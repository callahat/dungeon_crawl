defmodule DungeonCrawlWeb.LevelChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Action.{Move, Pull, Travel}
  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Player
  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.Scripting.{Runner, Program, Shape}

  alias DungeonCrawl.Scripting.Direction

  import Phoenix.HTML, only: [html_escape: 1]

  def join("level:" <> dungeon_instance_id_and_instance_id, _payload, socket) do
    [dungeon_instance_id, instance_id] = dungeon_instance_id_and_instance_id
                                         |> String.split(":")
                                         |> Enum.map(&String.to_integer(&1))

    {:ok, instance_registry} = Registrar.instance_registry(dungeon_instance_id)

    # make sure the instance is up and running
    {:ok, instance} = LevelRegistry.lookup_or_create(instance_registry, instance_id)

    # remove the player from the inactive map
    LevelProcess.run_with(instance, fn (%{inactive_players: inactive_players} = instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)

      if player_location && player_location.user_id_hash == socket.assigns.user_id_hash do
        socket = assign(socket, :instance_id, instance_id)
                 |> assign(:instance_registry, instance_registry)
                 |> assign(:item_last_used_at, 0)
        {
          {:ok, %{instance_id: instance_id}, socket},
          %{ instance_state | inactive_players: Map.delete(inactive_players, player_tile.id) }
        }
      else
        {
          {:error, %{message: "Could not join channel"}},
          instance_state
        }
      end
    end)
  end

  def terminate(_reason, socket) do
    # add the player to the inactive map
    case LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id) do
      {:ok, instance} ->
        LevelProcess.run_with(instance, fn (%{inactive_players: inactive_players} = instance_state) ->
          {_, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)
          inactive_players = if player_tile, do: Map.put(inactive_players, player_tile.id, 0), else: inactive_players
          {:ok, %{ instance_state | inactive_players: inactive_players }}
        end)

      _ ->
        nil
    end

    :ok
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (dungeon:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  def handle_in("light_torch", _, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)

    LevelProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)

      cond do
        is_nil(player_location) || is_nil(player_tile) ->
          {:ok, instance_state}
        instance_state.state_values[:visibility] != "dark" ->
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: "Don't need a torch here"}
          {:ok, instance_state}
        player_tile.parsed_state[:torches] > 0 ->
          new_torch_count = player_tile.parsed_state[:torches] - 1
          {_player_tile, instance_state} = Levels.update_tile_state(instance_state, player_tile, %{torches: new_torch_count, torch_light: 6, light_source: true, light_range: 6})
          {:ok, instance_state}
        true ->
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: "Don't have any torches"}
          {:ok, instance_state}
      end
    end)

    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("move", %{"direction" => direction}, socket) do
    _motion(direction, &Move.go/3, socket)
  end

  def handle_in("message_action", %{"item_slug" => item_slug}, socket) when not is_nil(item_slug) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    LevelProcess.run_with(instance, fn (instance_state) ->
      with {player_location, player_tile} when not is_nil(player_location) <-
             _player_location_and_tile(instance_state, socket.assigns.user_id_hash),
           true <- Enum.member?(player_tile.parsed_state[:equipment] || [], item_slug),
           {item, instance_state, _} when not is_nil(item) <- Levels.get_item(item_slug, instance_state) do
        Levels.update_tile_state(instance_state, player_tile, %{equipped: item_slug})
      else
        _ -> {:ok, instance_state}
      end
    end)

    {:noreply, socket}
  end

  def handle_in("message_action", %{"label" => label, "tile_id" => tile_id}, socket) do
    tile_id = case Integer.parse(tile_id) do
                {tile_id, ""} -> tile_id
                _ -> tile_id
              end

    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    LevelProcess.run_with(instance, fn (instance_state) ->
      with target_tile when not is_nil(target_tile) <- Levels.get_tile_by_id(instance_state, %{id: tile_id}),
           {player_location, player_tile} when not is_nil(player_location) <-
             _player_location_and_tile(instance_state, socket.assigns.user_id_hash),
           label <- String.downcase(label),
           true <- Levels.valid_message_action?(instance_state, player_tile.id, label),
           event_sender <- Map.merge(player_location, Map.take(player_tile, [:parsed_state])) do
        instance_state = Levels.remove_message_actions(instance_state, player_tile.id)
                         |> Levels.send_event(target_tile, label, event_sender)
        {:ok, instance_state}
      else
        _ -> {:ok, instance_state}
      end
    end)

    {:noreply, socket}
  end

  def handle_in("pull", %{"direction" => direction}, socket) do
    _motion(direction, &Pull.pull/3, socket)
  end

  def handle_in("respawn", %{}, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    LevelProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)

      if player_tile && not _player_alive(player_tile) && _game_active(player_tile, player_location) do
        {player_tile, instance_state} = Player.respawn(instance_state, player_tile)
        death_note = "You live again, after #{player_tile.parsed_state[:deaths]} death#{if player_tile.parsed_state[:deaths] > 1, do: "s"}"

        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: death_note}
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "stat_update", %{stats: Player.current_stats(instance_state, player_tile)}

        {:ok, instance_state}
      else
        {:ok, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  def handle_in("use_item", %{"direction" => direction}, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    socket = \
    LevelProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)
      instance_state = Levels.remove_message_actions(instance_state, player_tile.id)

      if _item_ready(socket) && _player_alive(player_tile) && _game_active(player_tile, player_location) do
        player_channel = "players:#{player_location.id}"

        {player_tile, instance_state} = Levels.update_tile_state(instance_state, player_tile, %{facing: direction})
        slug = player_tile.parsed_state[:equipped]

        case Levels.get_item(slug, instance_state) do
          {nil, _, :nothing_equipped} ->
            DungeonCrawlWeb.Endpoint.broadcast player_channel, "message", %{message: "You have nothing equipped"}
            {socket, instance_state}

          {nil, _, _} ->
            DungeonCrawlWeb.Endpoint.broadcast player_channel, "message", %{message: "Error: item '#{slug}' not found"}
            {socket, instance_state}

          {item, instance_state, _} ->
            _use_item(socket, instance_state, item, player_location)
        end
      else
        {socket, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  def handle_in("speak", %{"words" => words}, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    instance_state = LevelProcess.get_state(instance)
    {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)
    safe_words = \
    case String.split(words, ~r/^\/(?:level|dungeon|items)\b/, include_captures: true, trim: true, parts: 2) do
      ["/level", words] ->
        {:safe, safe_words} = html_escape String.trim(words)
        _send_message_to_other_players_in_instance(player_location, safe_words, instance_state)

      ["/dungeon", words] ->
        {:safe, safe_words} = html_escape String.trim(words)
        _send_message_to_other_players_in_dungeon(player_location, safe_words, socket.assigns.instance_registry)

      [words] ->
        {:safe, safe_words} = html_escape String.trim(words)
        _send_message_to_other_players_in_range(player_tile, player_location, safe_words, instance_state)
    end

    {:reply, {:ok, %{safe_words: "#{safe_words}"}}, socket}
  end

  def handle_in("use_door", %{"direction" => direction, "action" => action}, socket) when action == "OPEN" or action == "CLOSE" do
    _player_action_helper(
      %{"direction" => direction, "action" => action},
      "Cannot #{String.downcase(action)} that",
      socket)
    {:noreply, socket}
  end

  defp _motion(direction, move_func, socket) do
    direction = Direction.normalize_orthogonal(direction)
    _player_action_helper(%{"direction" => direction, "action" => "TOUCH"}, nil, socket)
    |> _continue_motion(direction, move_func, socket)
  end

  defp _continue_motion(:player_relocated, _direction, _move_func, socket) do
    {:reply, :ok, socket}
  end

  defp _continue_motion(_ok, direction, move_func, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)

    LevelProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)

      adjacent_level_id = _adjacent_level_id(instance_state, player_tile, direction)
      destination = Levels.get_tile(instance_state, player_tile, direction)

      cond do
        not _player_alive(player_tile) || not _game_active(player_tile, player_location) ->
          {:ok, instance_state}

        adjacent_level_id ->
          Travel.passage(player_location, %{adjacent_level_id: adjacent_level_id, edge: Direction.change_direction(direction, "reverse")}, instance_state)

        destination ->
          {player_tile, instance_state} = Levels.update_tile_state(instance_state, player_tile, %{already_touched: true})
          case move_func.(player_tile, destination, instance_state) do
            {:ok, _tile_changes, instance_state} ->
              {_, instance_state} = Levels.update_tile_state(instance_state, player_tile, %{already_touched: false})
              {:ok, instance_state}

            {:invalid, _tile_changes, instance_state} ->
              {_, instance_state} = Levels.update_tile_state(instance_state, player_tile, %{already_touched: false})
              {:ok, instance_state}
          end

        true -> {:ok, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  # todo: is sending a TOUCH message to all tiles (and not just the top one) a good idea?
  defp _player_action_helper(%{"direction" => direction, "action" => "TOUCH"}, _unhandled_event_message, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    LevelProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)
      instance_state = if player_tile, do: Levels.remove_message_actions(instance_state, player_tile.id),
                                       else: instance_state

      with true <- _player_alive(player_tile),
           true <- _game_active(player_tile, player_location),
           target_tiles when target_tiles != [] <- Levels.get_tiles(instance_state, player_tile, direction) do

        toucher = Map.merge(player_location, Map.take(player_tile, [:name, :parsed_state]))
        instance_state = target_tiles
                         |> Enum.reduce(instance_state, fn(target_tile, instance_state) ->
                               Levels.send_event(instance_state, target_tile, "TOUCH", toucher)
                             end)
        toucher_after_event = Levels.get_tile_by_id(instance_state, player_tile)
        if toucher_after_event && Map.take(toucher_after_event, [:row, :col]) == Map.take(player_tile, [:row, :col]) do
          {:ok, instance_state}
        else
          {:player_relocated, instance_state}
        end
      else
        _ -> {:ok, instance_state}
      end
    end)
  end

  defp _player_action_helper(%{"direction" => direction, "action" => action}, unhandled_event_message, socket) do
    {:ok, instance} = LevelRegistry.lookup_or_create(socket.assigns.instance_registry, socket.assigns.instance_id)
    LevelProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_tile(instance_state, socket.assigns.user_id_hash)
      instance_state = if player_tile, do: Levels.remove_message_actions(instance_state, player_tile.id),
                                       else: instance_state

      with true <- _player_alive(player_tile),
           true <- _game_active(player_tile, player_location),
           target_tile when not is_nil(target_tile) <- Levels.get_tile(instance_state, player_tile, direction) do
        if !Levels.responds_to_event?(instance_state, target_tile, action) && unhandled_event_message do
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: unhandled_event_message}
        end
        instance_state = Levels.send_event(instance_state, target_tile, action, Map.merge(player_location, Map.take(player_tile, [:name, :parsed_state])))

        {:ok, instance_state}
      else
        _ -> {:ok, instance_state}
      end
    end)
    {:noreply, socket}
  end

  defp _player_location_and_tile(instance_state, user_id_hash) do
    player_location = Levels.get_player_location(instance_state, user_id_hash)
    if player_location do
      player_tile = Levels.get_tile_by_id(instance_state, %{id: player_location.tile_instance_id})
      {player_location, player_tile}
    else
      {nil, nil}
    end
  end

  defp _player_alive(nil), do: false
  defp _player_alive(player_tile), do: player_tile.parsed_state[:health] > 0

  defp _game_active(nil, _), do: false
  defp _game_active(player_tile, player_location) do
    if player_tile.parsed_state[:gameover] == true do
      DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                         "gameover",
                                         Map.take(player_tile.parsed_state, [:score_id, :dungeon_id])
      false
    else
      true
    end
  end

  # TODO: this might be able to go away when every program is isolated to its own process.
  # although bullets will still probably collide if fired faster than every 100ms
  # since thats the rate at which they move.
  defp _item_ready(socket) do
    :os.system_time(:millisecond) - socket.assigns[:item_last_used_at] > 100
  end

  defp _send_message_to_other_players_in_range(player_tile, player_location, safe_msg, instance_state) do
    # this might be too expensive to use
    clear_coords = Shape.blob({instance_state, player_tile}, 10, false)
    audiable_coords = Shape.blob({instance_state, player_tile}, 15, false) -- clear_coords

    hearing_groups = \
    instance_state.player_locations
    |> Map.to_list()
    |> Enum.reject(fn({tile_id, _location}) -> tile_id == player_tile.id end)
    |> Enum.map(fn({tile_id, location}) -> {Levels.get_tile_by_id(instance_state, %{id: tile_id}), location} end)
    |> Enum.group_by(fn({tile, _location}) -> cond do
                                                Enum.member?(clear_coords, {tile.row, tile.col}) -> :ok
                                                Enum.member?(audiable_coords, {tile.row, tile.col}) -> :quiet
                                                true -> nil
                                              end
       end)

    (hearing_groups[:ok] || [])
    |> Enum.map(fn({_, location}) -> location.id end)
    |> _send_message_to_player("<b>#{Account.get_name(player_location.user_id_hash)}:</b> #{safe_msg}")

    (hearing_groups[:quiet] || [])
    |> Enum.map(fn({_, location}) -> location.id end)
    |> _send_message_to_player("You hear muffled voices")

    safe_msg
  end

  defp _send_message_to_other_players_in_instance(player_location, safe_msg, instance_state) do
    instance_state.player_locations
    |> Map.to_list()
    |> Enum.reject(fn({tile_id, _location}) -> tile_id == player_location.tile_instance_id end)
    |> Enum.map(fn({_tile_id, location}) -> location.id end)
    |> _send_message_to_player("<b>#{Account.get_name(player_location.user_id_hash)}</b> <i>to level</i><b>:</b> #{safe_msg}")

    safe_msg
  end

  defp _send_message_to_other_players_in_dungeon(player_location, safe_msg, instance_registry) do
    LevelRegistry.player_location_ids(instance_registry)
    |> Enum.reject(fn({_, tile_id, _number}) -> tile_id == player_location.tile_instance_id end)
    |> Enum.map(fn({location_id, _, _}) -> location_id end)
    |> _send_message_to_player("<b>#{Account.get_name(player_location.user_id_hash)}</b> <i>to dungeon</i><b>:</b> #{safe_msg}")

    safe_msg
  end

  defp _send_message_to_player([], _safe_msg), do: []
  defp _send_message_to_player([location_id | location_ids], safe_msg) do
    DungeonCrawlWeb.Endpoint.broadcast "players:#{location_id}",
                                       "message",
                                       %{message: safe_msg}
    _send_message_to_player(location_ids, safe_msg)
  end

  defp _adjacent_level_id(_, nil, _), do: nil
  defp _adjacent_level_id(instance_state, player_tile, "north"),
    do: player_tile.row == 0 && instance_state.adjacent_level_ids["north"]
  defp _adjacent_level_id(instance_state, player_tile, "south"),
    do: player_tile.row == instance_state.state_values[:rows]-1  && instance_state.adjacent_level_ids["south"]
  defp _adjacent_level_id(instance_state, player_tile, "east"),
    do: player_tile.col == instance_state.state_values[:cols]-1 && instance_state.adjacent_level_ids["east"]
  defp _adjacent_level_id(instance_state, player_tile, "west"),
    do: player_tile.col == 0 && instance_state.adjacent_level_ids["west"]
  defp _adjacent_level_id(_,_,_), do: nil

  defp _use_item(socket, instance_state, item, player_location) do
    player_channel = "players:#{player_location.id}"

    if instance_state.state_values[:pacifism] && item.weapon do
      DungeonCrawlWeb.Endpoint.broadcast player_channel, "message", %{message: "Can't use that here!"}
      {socket, instance_state}
    else
      # providing player_location as event_sender ensures any messages from executing the item's program
      # are sent to the proper player channel.
      # Run is called twice just in case a "take" or "give" command with a label jumps to that label
      # on insufficient/max thing reached which would put it into a wait state. Otherwise, the second
      # Runner.run is a noop.
      %{state: updated_state, program: program} =
        Runner.run(%Runner{program: item.program,
          object_id: player_location.tile_instance_id,
          state: instance_state,
          event_sender: player_location})
        |> Runner.run()
        |> Levels.handle_broadcasting() # any nontile_update broadcasts left

      player_tile = Levels.get_tile_by_id(updated_state, %{id: player_location.tile_instance_id})

      {player_tile, updated_state} =
        _update_equipment(player_tile, item.slug, program, updated_state)

      updated_stats = Player.current_stats(updated_state, player_tile)
      DungeonCrawlWeb.Endpoint.broadcast player_channel, "stat_update", %{stats: updated_stats}

      {assign(socket, :item_last_used_at, :os.system_time(:millisecond)), updated_state}
    end
  end

  defp _update_equipment(player_tile, item_slug, %Program{status: :dead}, state) do
    equipment = player_tile.parsed_state[:equipment] -- [item_slug]
    equipped = Enum.at(equipment, 0)

    Levels.update_tile_state(state, player_tile, %{equipment: equipment, equipped: equipped})
  end

  defp _update_equipment(player_tile, _item_slug, %Program{}, state) do
    {player_tile, state}
  end
end

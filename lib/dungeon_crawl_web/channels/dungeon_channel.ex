defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Action.{Move, Pull, Shoot, Travel}
  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Player

  alias DungeonCrawl.Scripting.Direction

  import Phoenix.HTML, only: [html_escape: 1]

  # TODO: what prevents someone from changing the instance_id to a dungeon they are not actually in (or allowed to be in)
  # and evesdrop on broadcasts?
  def join("dungeons:" <> instance_id, _payload, socket) do
    instance_id = String.to_integer(instance_id)

    # make sure the instance is up and running
    InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, instance_id)

    socket = assign(socket, :instance_id, instance_id)
             |> assign(:last_action_at, 0)
    {:ok, %{instance_id: instance_id}, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (dungeon:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("move", %{"direction" => direction}, socket) do
    _motion(direction, &Move.go/3, socket)
  end

  def handle_in("message_action", %{"label" => label, "tile_id" => tile_id}, socket) do
    tile_id = case Integer.parse(tile_id) do
                {tile_id, ""} -> tile_id
                _ -> tile_id
              end

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      with target_tile when not is_nil(target_tile) <- Instances.get_map_tile_by_id(instance_state, %{id: tile_id}),
           {player_location, player_tile} when not is_nil(player_location) <-
             _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash),
           label <- String.downcase(label),
           true <- Instances.valid_message_action?(instance_state, player_tile.id, label),
           event_sender <- Map.merge(player_location, Map.take(player_tile, [:parsed_state])) do
        instance_state = Instances.remove_message_actions(instance_state, player_tile.id)
                         |> Instances.send_event(target_tile, label, event_sender)
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
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

      if player_tile && not _player_alive(player_tile) do
        {player_tile, instance_state} = Player.respawn(instance_state, player_tile)
        death_note = "You live again, after #{player_tile.parsed_state[:deaths]} death#{if player_tile.parsed_state[:deaths] > 1, do: "s"}"

        payload = %{tiles: [
                     Map.put(Map.take(player_tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(player_tile))
                    ]}
        DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{instance_state.instance_id}", "tile_changes", payload
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: death_note}
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "stat_update", %{stats: Player.current_stats(instance_state, player_tile)}

        {:ok, instance_state}
      else
        {:ok, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  def handle_in("shoot", %{"direction" => direction}, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    socket = \
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)
      instance_state = Instances.remove_message_actions(instance_state, player_tile.id)

      if _shot_ready(socket) && _player_alive(player_tile) do
        player_channel = "players:#{player_location.id}"

        updated_state = case Shoot.shoot(player_location, direction, instance_state) do
                          {:invalid} ->
                            instance_state

                          {:no_ammo} ->
                            DungeonCrawlWeb.Endpoint.broadcast player_channel, "message", %{message: "Out of ammo"}
                            instance_state

                          {:ok, updated_instance} ->
                            updated_instance
                        end

        updated_stats = Player.current_stats(updated_state, %{id: player_location.map_tile_instance_id})
        DungeonCrawlWeb.Endpoint.broadcast player_channel, "stat_update", %{stats: updated_stats}

        {assign(socket, :last_action_at, :os.system_time(:millisecond)), updated_state}
      else
        {socket, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  def handle_in("speak", %{"words" => words}, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    instance_state = InstanceProcess.get_state(instance)
    {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

    safe_words = \
    case String.split(words, ~r/^\/(?:level|dungeon)\b/, include_captures: true, trim: true, parts: 2) do
      ["/level", words] ->
        {:safe, safe_words} = html_escape String.trim(words)
        _send_message_to_other_players_in_instance(player_location, safe_words, instance_state)

      ["/dungeon", words] ->
        {:safe, safe_words} = html_escape String.trim(words)
        _send_message_to_other_players_in_dungeon(player_location, safe_words, socket.assigns.instance_id)

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
  end

  defp _motion(direction, move_func, socket) do
    direction = Direction.normalize_orthogonal(direction)
    _player_action_helper(%{"direction" => direction, "action" => "TOUCH"}, nil, socket)

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

      adjacent_map_id = _adjacent_map_id(instance_state, player_tile, direction)
      destination = Instances.get_map_tile(instance_state, player_tile, direction)

      cond do
        not _player_alive(player_tile) ->
          {:ok, instance_state}

        adjacent_map_id ->
          Travel.passage(player_location, %{adjacent_map_id: adjacent_map_id, edge: Direction.change_direction(direction, "reverse")}, instance_state)

        destination ->
          case move_func.(player_tile, destination, instance_state) do
            {:ok, tile_changes, instance_state} ->
              broadcast socket,
                        "tile_changes",
                        %{tiles: tile_changes
                                  |> Map.to_list
                                  |> Enum.map(fn({_coords, tile}) ->
                                    Map.put(Map.take(tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
                                  end)}
              {:ok, instance_state}

            {:invalid} ->
              {:ok, instance_state}
          end

        true -> {:ok, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  defp _player_action_helper(%{"direction" => direction, "action" => action}, unhandled_event_message, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)
      instance_state = Instances.remove_message_actions(instance_state, player_tile.id)

      with true <- _player_alive(player_tile),
           target_tile when not is_nil(target_tile) <- Instances.get_map_tile(instance_state, player_tile, direction) do
        if !Instances.responds_to_event?(instance_state, target_tile, action) && unhandled_event_message do
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: unhandled_event_message}
        end
        instance_state = Instances.send_event(instance_state, target_tile, action, Map.merge(player_location, Map.take(player_tile, [:name, :parsed_state])))

        {:ok, instance_state}
      else
        _ -> {:ok, instance_state}
      end
    end)
    {:noreply, socket}
  end

  defp _player_location_and_map_tile(instance_state, user_id_hash) do
    player_location = Instances.get_player_location(instance_state, user_id_hash)
    if player_location do
      player_map_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})
      {player_location, player_map_tile}
    else
      {nil, nil}
    end
  end

  defp _player_alive(nil), do: false
  defp _player_alive(player_map_tile), do: player_map_tile.parsed_state[:health] > 0

  # TODO: this might be able to go away when every program is isolated to its own process.
  # although bullets will still probably collide if fired faster than every 100ms
  # since thats the rate at which they move.
  defp _shot_ready(socket) do
    :os.system_time(:millisecond) - socket.assigns[:last_action_at] > 100
  end

  defp _send_message_to_other_players_in_range(player_tile, player_location, safe_msg, instance_state) do
    # this might be too expensive to use
    clear_coords = DungeonCrawl.Scripting.Shape.blob({instance_state, player_tile}, 10, false)
    audiable_coords = DungeonCrawl.Scripting.Shape.blob({instance_state, player_tile}, 15, false) -- clear_coords

    hearing_groups = \
    instance_state.player_locations
    |> Map.to_list()
    |> Enum.reject(fn({map_tile_id, _location}) -> map_tile_id == player_tile.id end)
    |> Enum.map(fn({map_tile_id, location}) -> {Instances.get_map_tile_by_id(instance_state, %{id: map_tile_id}), location} end)
    |> Enum.group_by(fn({map_tile, _location}) -> cond do
                                                    Enum.member?(clear_coords, {map_tile.row, map_tile.col}) -> :ok
                                                    Enum.member?(audiable_coords, {map_tile.row, map_tile.col}) -> :quiet
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
    |> Enum.reject(fn({map_tile_id, _location}) -> map_tile_id == player_location.map_tile_instance_id end)
    |> Enum.map(fn({_map_tile_id, location}) -> location.id end)
    |> _send_message_to_player("<b>#{Account.get_name(player_location.user_id_hash)}</b> <i>to level</i><b>:</b> #{safe_msg}")

    safe_msg
  end

  defp _send_message_to_other_players_in_dungeon(player_location, safe_msg, instance_id) do
    Repo.preload(DungeonCrawl.DungeonInstances.get_map(instance_id), [map_set: :locations]).map_set.locations
    |> Enum.map(fn(location) -> {location.id, location.map_tile_instance_id} end)
    |> Enum.reject(fn({_, tile_id}) -> tile_id == player_location.map_tile_instance_id end)
    |> Enum.map(fn({location_id, _}) -> location_id end)
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

  defp _adjacent_map_id(instance_state, player_tile, "north"),
    do: player_tile.row == 0 && instance_state.adjacent_map_ids["north"]
  defp _adjacent_map_id(instance_state, player_tile, "south"),
    do: player_tile.row == instance_state.state_values[:rows]-1  && instance_state.adjacent_map_ids["south"]
  defp _adjacent_map_id(instance_state, player_tile, "east"),
    do: player_tile.col == instance_state.state_values[:cols]-1 && instance_state.adjacent_map_ids["east"]
  defp _adjacent_map_id(instance_state, player_tile, "west"),
    do: player_tile.col == 0 && instance_state.adjacent_map_ids["west"]
  defp _adjacent_map_id(_,_,_), do: nil
end

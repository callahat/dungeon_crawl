defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Action.{Move, Pull, Shoot}
  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Player

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

  def handle_in("pull", %{"direction" => direction}, socket) do
    _motion(direction, &Pull.pull/3, socket)
  end

  def handle_in("respawn", %{}, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

      if player_tile && not _player_alive(player_tile) do
        {player_tile, state} = Player.respawn(instance_state, player_tile)
        death_note = "You live again, after #{player_tile.parsed_state[:deaths]} death#{if player_tile.parsed_state[:deaths] > 1, do: "s"}"

        payload = %{tiles: [
                     Map.put(Map.take(player_tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(player_tile))
                    ]}
        DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.instance_id}", "tile_changes", payload
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: death_note}
        DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "stat_update", %{stats: Player.current_stats(state, player_tile)}

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
    # This will reach everyone in the instance.
    # TODO: different speak commands to explicitly reach everyone in the instance, dungeon (map set),
    # and the default speak will only be heard by those in non blocked (soft block ok) line of sight
    {:safe, safe_words} = html_escape words

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, _player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

      _send_message_to_other_players_in_instance(player_location, safe_words, instance_state)

      {:ok, instance_state}
    end)

    {:reply, {:ok, %{safe_words: "#{safe_words}"}}, socket}
  end

  def handle_in("use_door", %{"direction" => direction, "action" => action}, socket) when action == "OPEN" or action == "CLOSE" do
    _player_action_helper(
      %{"direction" => direction, "action" => action},
      "Cannot #{String.downcase(action)} that",
      socket)
  end

  defp _motion(direction, move_func, socket) do
    _player_action_helper(%{"direction" => direction, "action" => "TOUCH"}, nil, socket)

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {_player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

      with true <- _player_alive(player_tile),
           destination <- Instances.get_map_tile(instance_state, player_tile, direction) do

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

      else
        _ -> {:ok, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  defp _player_action_helper(%{"direction" => direction, "action" => action}, unhandled_event_message, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      {player_location, player_tile} = _player_location_and_map_tile(instance_state, socket.assigns.user_id_hash)

      with true <- _player_alive(player_tile),
           target_tile when not is_nil(target_tile) <- Instances.get_map_tile(instance_state, player_tile, direction) do
        if !Instances.responds_to_event?(instance_state, target_tile, action) && unhandled_event_message do
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: unhandled_event_message}
        end
        instance_state = Instances.send_event(instance_state, target_tile, action, Map.merge(player_location, Map.take(player_tile, [:parsed_state])))

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

  defp _send_message_to_other_players_in_instance(player_location, safe_msg, instance_state) do
    instance_state.player_locations
    |> Map.to_list()
    |> Enum.reject(fn({map_tile_id, _location}) -> map_tile_id == player_location.map_tile_instance_id end)
    |> Enum.each(fn({_map_tile_id, location}) ->
         DungeonCrawlWeb.Endpoint.broadcast "players:#{location.id}",
                                            "message",
                                            %{message: "<b>#{Account.get_name(player_location.user_id_hash)}:</b> #{safe_msg}"}
       end)
  end
end

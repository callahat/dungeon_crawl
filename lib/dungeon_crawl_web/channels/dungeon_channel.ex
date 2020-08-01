defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Action.{Move, Pull, Shoot}
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Player

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
    if _player_alive(socket) do
      _motion(direction, &Move.go/3, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_in("pull", %{"direction" => direction}, socket) do
    if _player_alive(socket) do
      _motion(direction, &Pull.pull/3, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_in("shoot", %{"direction" => direction}, socket) do
    if _player_alive(socket) && _shot_ready(socket) do
      {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
      InstanceProcess.run_with(instance, fn (instance_state) ->
        player_location = Instances.get_player_location(instance_state, socket.assigns.user_id_hash)
        player_channel = "players:#{player_location.id}"

        updated_state = case Shoot.shoot(player_location, direction, instance_state) do
                          {:invalid} ->
                            instance_state

                          {:no_ammo} ->
                            DungeonCrawlWeb.Endpoint.broadcast player_channel, "message", %{message: "Out of ammo"}
                            instance_state

                          {:shot, spawn_tile} ->
                            Instances.send_event(instance_state, spawn_tile, "shot", player_location)

                          {:ok, updated_instance} ->
                            updated_instance
                        end

        updated_stats = Player.current_stats(updated_state, %{id: player_location.map_tile_instance_id})
        DungeonCrawlWeb.Endpoint.broadcast player_channel, "stat_update", %{stats: updated_stats}

        {:ok, updated_state}
      end)

      {:reply, :ok, assign(socket, :last_action_at, :os.system_time(:millisecond))}
    else
      {:reply, :ok, socket}
    end
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
      player_location = Instances.get_player_location(instance_state, socket.assigns.user_id_hash)
      player_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})
      destination = Instances.get_map_tile(instance_state, player_tile, direction)

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
    end)

    {:reply, :ok, socket}
  end

  defp _player_action_helper(%{"direction" => direction, "action" => action}, unhandled_event_message, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      player_location = Instances.get_player_location(instance_state, socket.assigns.user_id_hash)
      player_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})
      target_tile = Instances.get_map_tile(instance_state, player_tile, direction)

      if target_tile do
        if !Instances.responds_to_event?(instance_state, target_tile, action) && unhandled_event_message do
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: unhandled_event_message}
        end
        instance_state = Instances.send_event(instance_state, target_tile, action, Map.merge(player_location, Map.take(player_tile, [:parsed_state])))

        {:ok, instance_state}
      else
        {:ok, instance_state}
      end
    end)
    {:noreply, socket}
  end

  defp _player_alive(socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      player_location = Instances.get_player_location(instance_state, socket.assigns.user_id_hash)
      {Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id}).parsed_state[:health] > 0,
       instance_state}
    end)
  end

  # TODO: this might be able to go away when every program is isolated to its own process.
  # although bullets will still probably collide if fired faster than every 100ms
  # since thats the rate at which they move.
  defp _shot_ready(socket) do
    :os.system_time(:millisecond) - socket.assigns[:last_action_at] > 100
  end
end

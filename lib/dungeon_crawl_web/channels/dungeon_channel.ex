defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Action.{Move, Shoot}
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess

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
    _player_action_helper(%{"direction" => direction, "action" => "TOUCH"}, nil, socket)

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      player_location = Player.get_location!(socket.assigns.user_id_hash)
      player_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})
      destination = Instances.get_map_tile(instance_state, player_tile, direction)

      case Move.go(player_tile, destination, instance_state) do
        {:ok, %{new_location: new_location, old_location: old}, instance_state} ->
          broadcast socket,
                    "tile_changes",
                    %{tiles: [
                       Map.put(Map.take(new_location, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(new_location)),
                       Map.put(Map.take(old, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(old))
                      ]}
          {:ok, instance_state}

        {:invalid} ->
          {:ok, instance_state}
      end
    end)

    {:reply, :ok, socket}
  end

  def handle_in("shoot", %{"direction" => direction}, socket) do
    if _shot_ready(socket) do
      {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
      InstanceProcess.run_with(instance, fn (instance_state) ->
        player_location = Player.get_location!(socket.assigns.user_id_hash)
        player_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})

        case Shoot.shoot(player_tile, direction, instance_state) do
          {:invalid} ->
            {:ok, instance_state}

          {:shot, spawn_tile} ->
            {:ok, Instances.send_event(instance_state, spawn_tile, "shot", player_location)}

          {:ok, updated_instance} ->
            {:ok, updated_instance}
        end
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

  defp _player_action_helper(%{"direction" => direction, "action" => action}, unhandled_event_message, socket) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)
    InstanceProcess.run_with(instance, fn (instance_state) ->
      player_location = Player.get_location!(socket.assigns.user_id_hash)
      player_tile = Instances.get_map_tile_by_id(instance_state, %{id: player_location.map_tile_instance_id})
      target_tile = Instances.get_map_tile(instance_state, player_tile, direction)

      if target_tile do
        if !Instances.responds_to_event?(instance_state, target_tile, action) && unhandled_event_message do
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: unhandled_event_message}
        end
        instance_state = Instances.send_event(instance_state, target_tile, action, player_location)

        {:ok, instance_state}
      else
        {:ok, instance_state}
      end
    end)
    {:noreply, socket}
  end

  # TODO: this might be able to go away when every program is isolated to its own process.
  # although bullets will still probably collide if fired faster than every 100ms
  # since thats the rate at which they move.
  defp _shot_ready(socket) do
    :os.system_time(:millisecond) - socket.assigns[:last_action_at] > 100
  end
end

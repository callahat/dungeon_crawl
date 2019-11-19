defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.DungeonInstances, as: Dungeon
  alias DungeonCrawl.Action.{Move}
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess

  # TODO: what prevents someone from changing the instance_id to a dungeon they are not actually in (or allowed to be in)
  # and evesdrop on broadcasts?
  def join("dungeons:" <> instance_id, _payload, socket) do
    instance_id = String.to_integer(instance_id)

    # make sure the instance is up and running
    InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, instance_id)

    {:ok, %{instance_id: instance_id}, assign(socket, :instance_id, instance_id)}
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
    player_location = Player.get_location!(socket.assigns.user_id_hash) |> Repo.preload(:map_tile)
    destination = Dungeon.get_map_tile(player_location.map_tile, direction)

    case Move.go(player_location.map_tile, destination) do
      {:ok, %{new_location: new_location, old_location: old}} ->
        broadcast socket,
                  "tile_changes",
                  %{tiles: [
                     Map.put(Map.take(new_location, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(new_location)),
                     Map.put(Map.take(old, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(old))
                    ]}

      {:invalid} ->
        :ok
    end

    {:reply, :ok, socket}
  end

  def handle_in("use_door", %{"direction" => direction, "action" => action}, socket) when action == "OPEN" or action == "CLOSE" do
    _player_action_helper(
      %{"direction" => direction, "action" => action},
      "Cannot #{String.downcase(action)} that",
      socket)
  end

  def handle_in("step", %{"direction" => direction}, socket) do
    _player_action_helper(%{"direction" => direction, "action" => "TOUCH"}, nil, socket)
  end

  defp _player_action_helper(%{"direction" => direction, "action" => action}, unhandled_event_message, socket) do
    player_location = Player.get_location!(socket.assigns.user_id_hash) |> Repo.preload(:map_tile)
    target_tile = Dungeon.get_map_tile(player_location.map_tile, direction) |> Repo.preload(:tile_template)

    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, socket.assigns.instance_id)

    InstanceProcess.send_event(instance, target_tile.id, action, player_location)

    if !InstanceProcess.responds_to_event?(instance, target_tile.id, action) && unhandled_event_message do
      DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: unhandled_event_message}
    end
    {:noreply, socket}
  end

  defp _handle_broadcasts(_socket, []), do: nil
  defp _handle_broadcasts(socket, [[event, payload] | broadcasts]) do
    _handle_broadcasts(socket, broadcasts)
    broadcast socket, event, payload
  end

  defp _reply_payload([]), do: :ok
  defp _reply_payload([response | responses]) do
    case _reply_payload(responses) do
      {:error, %{msg: msgs}} ->
        {:error, %{msg: "#{msgs}; #{response}"}}

      _ ->
        {:error, %{msg: response}}
    end
  end
end

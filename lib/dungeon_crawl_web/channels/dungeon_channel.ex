defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.DungeonInstances, as: Dungeon
  alias DungeonCrawl.Action.{Move,Door}

  def join("dungeons:" <> instance_id, _payload, socket) do
    instance_id = String.to_integer(instance_id)

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
        broadcast socket, "tile_update", %{new_location: Map.take(new_location, [:row, :col]),
                                           old_location: %{row: old.row, col: old.col, tile: DungeonCrawlWeb.SharedView.tile_and_style(old)}}

      {:invalid} ->
        :ok
    end

    {:reply, :ok, socket}
  end

  def handle_in("use_door", %{"direction" => direction, "action" => action}, socket) when action == "OPEN" or action == "CLOSE" do
    player_location = Player.get_location!(socket.assigns.user_id_hash) |> Repo.preload(:map_tile)
    target_door = Dungeon.get_map_tile(player_location.map_tile, direction) |> Repo.preload(:tile_template)

    # TODO: eventually grab the running program and have it try the label instead of this.
    # Once its more of a step (instead of run everything til a halt condition) it might be better to have the runner return
    # information such as events to broadcast (instead of broadcasting the event itself)
    script = target_door.script
    {:ok, prog} = DungeonCrawl.Scripting.Parser.parse script

    if prog.labels[action] do
      %{program: prog, object: target_door} = DungeonCrawl.Scripting.Runner.run %{program: prog, object: target_door, label: action}
      _handle_broadcasts(socket, prog.broadcasts)
      {:reply, _reply_payload(prog.responses), socket}
    else
      {:reply, {:error, %{msg: "Cannot #{String.downcase(action)} that"}}, socket}
    end
  end

  def handle_in("step", %{"direction" => direction}, socket) do
    player_location = Player.get_location!(socket.assigns.user_id_hash) |> Repo.preload(:map_tile)
    target_tile = Dungeon.get_map_tile(player_location.map_tile, direction) |> Repo.preload(:tile_template)

    script = target_tile.script
    {:ok, prog} = DungeonCrawl.Scripting.Parser.parse script

    if prog.labels["TOUCH"] do
      %{program: prog, object: target_tile} = DungeonCrawl.Scripting.Runner.run %{program: prog, object: target_tile, label: "TOUCH"}
      _handle_broadcasts(socket, prog.broadcasts)
      {:reply, _reply_payload(prog.responses), socket}
    else
      {:noreply, socket}
    end
  end

  defp _handle_broadcasts(socket, []), do: nil
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

  # Helper wrapper for broadcasting from outside the module
  def broadcast_event(socket, event, payload) do
    broadcast socket, event, payload
  end
end

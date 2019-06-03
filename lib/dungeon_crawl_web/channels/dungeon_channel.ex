defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Action.{Move,Door}

  def join("dungeons:" <> dungeon_id, _payload, socket) do
    dungeon_id = String.to_integer(dungeon_id)

    {:ok, %{dungeon_id: dungeon_id}, assign(socket, :dungeon_id, dungeon_id)}
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
    player_location = Player.get_location!(socket.assigns.user_id_hash)
    destination = Dungeon.get_map_tile(player_location, direction)

    case Move.go(player_location, destination) do
      {:ok, %{new_location: new_location, old_location: old_location}} ->
        old = old_location |> Repo.preload(:tile_template)

        broadcast socket, "tile_update", %{new_location: Map.take(new_location, [:row, :col]), old_location: %{row: old.row, col: old.col, tile: old.tile_template.character}}

      {:invalid} ->
        :ok
    end

    {:reply, :ok, socket}
  end

  def handle_in("use_door", %{"direction" => direction, "action" => action}, socket) when action == "open" or action == "close" do
    player_location = Player.get_location!(socket.assigns.user_id_hash)
    target_door = Dungeon.get_map_tile(player_location, direction)

    case apply(Door, String.to_atom(action), [target_door]) do
      { :ok, results = %{door_location: %{row: _, col: _, tile: _}} } ->
        broadcast socket, "door_changed", results
        {:reply, :ok, socket}

      {:invalid} ->
        {:reply, {:error, %{msg: "Cannot #{action} that"}}, socket}
    end
  end
end

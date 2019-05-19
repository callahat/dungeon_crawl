defmodule DungeonCrawlWeb.DungeonChannel do
  use DungeonCrawl.Web, :channel

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon

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

    target_coords = _target_location(direction, player_location.row, player_location.col)

    proposed_location = _proposed_player_location(player_location, target_coords)

    if _valid_move(Map.merge(player_location, proposed_location.changes)) do
      standing_on = Dungeon.get_map_tile(player_location.dungeon_id, player_location.row, player_location.col)
      # TODO: most of this should belong in its own 'action' module
      new_location = proposed_location |> Repo.update!
      broadcast socket, "tile_update", %{new_location: %{row: new_location.row, col: new_location.col}, old_location: %{row: standing_on.row, col: standing_on.col, tile: standing_on.tile}}
    end

    {:reply, :ok, socket}
  end

  def handle_in("use_door", %{"direction" => direction, "action" => action}, socket) do
    {door, actioned_door} = if action == "open", do: {"+","'"}, else: {"'","+"}

    player_location = Player.get_location!(socket.assigns.user_id_hash)
    target_coords = _target_location(direction, player_location.row, player_location.col)
    door_location = Dungeon.get_map_tile(player_location.dungeon_id, target_coords.row, target_coords.col)

    if _door_state(door_location, door) do
      door = Dungeon.update_map_tile!(door_location, actioned_door)
      broadcast socket, "door_changed", %{door_location: %{row: door.row, col: door.col, tile: door.tile}}
      {:reply, :ok, socket}
    else
      {:reply, {:error, %{msg: "Cannot #{action} that"}}, socket}
    end
  end

  # returns a amp representing the target coordinates given a direction word and starting coordinates
  defp _target_location(direction, row, col) do
     {d_row, d_col} = case direction do
                        "up"    -> {-1,  0}
                        "down"  -> { 1,  0}
                        "left"  -> { 0, -1}
                        "right" -> { 0,  1}
                        _       -> { 0,  0}
                      end

    %{row: row + d_row, col: col + d_col}
  end

  defp _valid_move(%{dungeon_id: dungeon_id, row: row, col: col}) do
    case Dungeon.get_map_tile(dungeon_id, row, col).tile do
      "." -> true
      "'" -> true
      _   -> false
    end
  end

  defp _door_state(%{dungeon_id: dungeon_id, row: row, col: col}, door) do
    case Dungeon.get_map_tile(dungeon_id, row, col).tile do
      ^door -> true
      _     -> false
    end
  end

  defp _proposed_player_location(player_location, new_coordinates = %{row: _row, col: _col}) do
    player_location
    |> Player.change_location(new_coordinates)
  end

end

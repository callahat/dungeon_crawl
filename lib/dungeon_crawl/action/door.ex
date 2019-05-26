defmodule DungeonCrawl.Action.Door do
  alias DungeonCrawl.Dungeon

  def open(door_location) do
    if _door_state(door_location, "+") do
      door = Dungeon.update_map_tile!(door_location, "'")

      {:ok, %{door_location: %{row: door.row, col: door.col, tile: door.tile}}}
    else
      {:invalid}
    end
  end

  def close(door_location) do
    if _door_state(door_location, "'") do
      door = Dungeon.update_map_tile!(door_location, "+")

      {:ok, %{door_location: %{row: door.row, col: door.col, tile: door.tile}}}
    else
      {:invalid}
    end
  end

  defp _door_state(%{dungeon_id: dungeon_id, row: row, col: col}, door) do
    case Dungeon.get_map_tile(dungeon_id, row, col).tile do
      ^door -> true
      _     -> false
    end
  end
end

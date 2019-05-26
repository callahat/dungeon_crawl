defmodule DungeonCrawl.Action.DoorTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Door
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.MapTile

  test "open/1 opens a closed door" do
    dungeon = insert_stubbed_dungeon(%{}, [%{row: 1, col: 1, tile: "+"}])
    target_door = Dungeon.get_map_tile!(%{dungeon_id: dungeon.id, row: 1, col: 1})

    assert {:ok, %{door_location: %{row: 1, col: 1, tile: "'"}}} = Door.open(target_door)
    assert Repo.get_by(MapTile, %{row: 1, col: 1, tile: "'"})
  end

  test "open/1 is invalid for anything other than a closed door" do
    dungeon = insert_stubbed_dungeon(%{}, [%{row: 4, col: 5, tile: "#"}])
    target_door = Dungeon.get_map_tile!(%{dungeon_id: dungeon.id, row: 4, col: 5})

    assert {:invalid} = Door.open(target_door)
    assert Repo.get_by(MapTile, %{row: 4, col: 5, tile: "#"})
  end

  test "close/1 closes an open door" do
    dungeon = insert_stubbed_dungeon(%{}, [%{row: 2, col: 3, tile: "'"}])
    target_door = Dungeon.get_map_tile!(%{dungeon_id: dungeon.id, row: 2, col: 3})

    assert {:ok, %{door_location: %{row: 2, col: 3, tile: "+"}}} = Door.close(target_door)
    assert Repo.get_by(MapTile, %{row: 2, col: 3, tile: "+"})
  end

  test "close/1 is invalid for anything other than an open door" do
    dungeon = insert_stubbed_dungeon(%{}, [%{row: 8, col: 9, tile: "#"}])
    target_door = Dungeon.get_map_tile!(%{dungeon_id: dungeon.id, row: 8, col: 9})

    assert {:invalid} = Door.close(target_door)
    assert Repo.get_by(MapTile, %{row: 8, col: 9, tile: "#"})
  end
end


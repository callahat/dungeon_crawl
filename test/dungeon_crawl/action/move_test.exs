defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.Dungeon.MapTile
  alias DungeonCrawl.Player.Location

  test "moving to an empty floor space" do
    dungeon = insert_stubbed_dungeon(%{}, [%{row: 1, col: 2, tile: "."}])
    player_location = insert_player_location(%{dungeon_id: dungeon.id, row: 1, col: 2})
    destination = %MapTile{dungeon_id: dungeon.id, row: 1, col: 1, tile: "."}

    assert {:ok, %{new_location: new_location, old_location: old_location}} = Move.go(player_location, destination)
    assert %MapTile{row: 1, col: 2, tile: "."} = old_location
    assert %Location{row: 1, col: 1} = new_location
  end

  test "moving to a bad space" do
    dungeon = insert_stubbed_dungeon(%{}, [%{row: 1, col: 2, tile: "."}])
    player_location = insert_player_location(%{dungeon_id: dungeon.id, row: 1, col: 2})
    destination = %MapTile{dungeon_id: dungeon.id, row: 1, col: 1, tile: "#"}

    assert {:invalid} = Move.go(player_location, destination)
  end
end


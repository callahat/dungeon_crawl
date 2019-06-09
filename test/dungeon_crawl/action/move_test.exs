defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.Dungeon.MapTile
  alias DungeonCrawl.Player.Location

  test "moving to an empty floor space" do
    floor = insert_tile_template() # floor by default

    dungeon = insert_stubbed_dungeon(%{}, [%{row: 1, col: 2, tile: floor.character, tile_template_id: floor.id}])
    player_location = insert_player_location(%{dungeon_id: dungeon.id, row: 1, col: 2})
    destination = %MapTile{dungeon_id: dungeon.id, row: 1, col: 1, tile_template_id: floor.id}

    assert {:ok, %{new_location: new_location, old_location: old_location}} = Move.go(player_location, destination)
    assert %MapTile{row: 1, col: 2, tile_template_id: floor_id} = old_location
    assert floor_id == floor.id
    assert %Location{row: 1, col: 1} = new_location
  end

  test "moving to a bad space" do
    impassable_floor = insert_tile_template(%{responders: "{}"})

    dungeon = insert_stubbed_dungeon(%{}, [%{row: 1, col: 2, tile: impassable_floor.character, tile_template_id: impassable_floor.id}])
    player_location = insert_player_location(%{dungeon_id: dungeon.id, row: 1, col: 2})
    destination = %MapTile{dungeon_id: dungeon.id, row: 1, col: 1, tile_template_id: impassable_floor.id}

    assert {:invalid} = Move.go(player_location, destination)
  end
end


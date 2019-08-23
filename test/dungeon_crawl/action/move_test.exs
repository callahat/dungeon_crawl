defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances, as: Dungeon
  alias DungeonCrawl.DungeonInstances.MapTile

  test "moving to an empty floor space" do
    floor_tt = insert_tile_template() # floor by default
    dungeon = insert_stubbed_dungeon_instance()
    floor_a = Dungeon.create_map_tile!(%{map_instance_id: dungeon.id, row: 1, col: 2, tile_template_id: floor_tt.id})
    floor_b = Dungeon.create_map_tile!(%{map_instance_id: dungeon.id, row: 1, col: 1, tile_template_id: floor_tt.id})

    player_location = insert_player_location(%{map_instance_id: dungeon.id, row: 1, col: 2}) |> Repo.preload(:map_tile)

    destination = Dungeon.get_map_tile(dungeon.id, 1, 1)

    assert {:ok, %{new_location: new_location, old_location: old_location}} = Move.go(player_location.map_tile, destination)
    assert %MapTile{row: 1, col: 2, tile_template_id: floor_tt_id} = old_location
    assert floor_tt_id == floor_tt.id
    assert %MapTile{row: 1, col: 1} = new_location
    assert Dungeon.get_map_tiles(dungeon.id, 1, 2) == [floor_a]
    assert Dungeon.get_map_tiles(dungeon.id, 1, 1) == [Repo.preload(player_location, :map_tile, force: true).map_tile,
                                                       floor_b]
  end

  test "moving to a bad space" do
    impassable_floor = insert_tile_template(%{responders: "{}"})

    dungeon = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 1, col: 2, tile_template_id: impassable_floor.id, z_index: 0}, Map.take(impassable_floor, [:character,:color,:background_color]))])
    player_location = insert_player_location(%{map_instance_id: dungeon.id, row: 1, col: 2}) |> Repo.preload(:map_tile)
    destination = %MapTile{map_instance_id: dungeon.id, row: 1, col: 1, tile_template_id: impassable_floor.id}

    assert {:invalid} = Move.go(player_location.map_tile, destination)
  end

  test "moving to something that is not a map tile" do
    dungeon = insert_stubbed_dungeon_instance()
    player_location = insert_player_location(%{map_instance_id: dungeon.id, row: 1, col: 2}) |> Repo.preload(:map_tile)

    assert {:invalid} = Move.go(player_location.map_tile, nil)
  end
end


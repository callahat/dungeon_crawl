defmodule DungeonCrawl.DungeonProcesses.InstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Instances

  setup do
    map_tile =        %{id: 999, row: 1, col: 2, z_index: 0, character: "B", state: "", script: ""}
    map_tile_south_1  = %{id: 997, row: 1, col: 3, z_index: 1, character: "S", state: "", script: ""}
    map_tile_south_2  = %{id: 998, row: 1, col: 3, z_index: 0, character: "X", state: "", script: ""}
    dungeon_map_tiles = [map_tile, map_tile_south_1, map_tile_south_2]

    instance_id = InstanceRegistry.create(DungeonInstanceRegistry, nil, dungeon_map_tiles)
    %{instance_id: instance_id}
  end

  test "create_map_tile/1 creates a map tile", %{instance_id: instance_id} do
    new_map_tile = %{id: 1, row: 4, col: 4, z_index: 0, character: "M", state: "", script: "", map_instance_id: instance_id}
    assert %{id: 1, character: "M"} = Instances.create_map_tile(new_map_tile)

    # returns the existing tile if it already exists by id
    assert %{id: 1, character: "M"} = Instances.create_map_tile(Map.put(new_map_tile, :character, "O"))
  end

  test "get_map_tile_by_id/1 gets the map tile for the id", %{instance_id: instance_id} do
    assert %{id: 999} = Instances.get_map_tile_by_id(%{id: 999, map_instance_id: instance_id})
  end

  test "get_map_tile/1 gets the top map tile at the given coordinates", %{instance_id: instance_id} do
    assert %{id: 999} = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: instance_id})
  end

  test "get_map_tile/2 gets the top map tile in the given direction", %{instance_id: instance_id} do
    assert %{id: 997} = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: instance_id}, "east")
  end

  test "get_map_tiles/2 gets the map tiles in the given direction", %{instance_id: instance_id} do
    assert [map_tile_1, map_tile_2] = Instances.get_map_tiles(%{row: 1, col: 2, map_instance_id: instance_id}, "east")
    assert %{id: 997} = map_tile_1
    assert %{id: 998} = map_tile_2
  end

  test "get_map_tiles/2 gets empty array in the given direction", %{instance_id: instance_id} do
    assert [] == Instances.get_map_tiles(%{row: 1, col: 2, map_instance_id: instance_id}, "north")
  end

  test "update_map_tile/2 updates the map tile", %{instance_id: instance_id} do
    map_tile = Instances.get_map_tile(%{id: 999, row: 1, col: 2, map_instance_id: instance_id})
    new_attributes = %{id: 333, row: 2, col: 2, character: "M"}

    assert Map.merge(map_tile, %{row: 2, col: 2, character: "M"}) == Instances.update_map_tile(map_tile, new_attributes)
  end

  test "delete_map_tile/1 deletes the map tile", %{instance_id: instance_id} do
    map_tile = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: instance_id})

    refute Instances.delete_map_tile(map_tile)
    assert [] == Instances.get_map_tiles(map_tile)
  end
end

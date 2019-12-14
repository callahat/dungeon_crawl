defmodule DungeonCrawl.DungeonProcesses.InstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Instances

  setup do
    #instance_registry = start_supervised!(InstanceRegistry)
    map_tile =       %{id: 999, row: 1, col: 2, z_index: 0, character: "B", state: "", script: ""}
    map_tile_south = %{id: 998, row: 1, col: 3, z_index: 0, character: "S", state: "", script: ""}
    dungeon_map_tiles = [map_tile, map_tile_south]

    instance_id = InstanceRegistry.create(DungeonInstanceRegistry, nil, dungeon_map_tiles)
    %{instance_id: instance_id}
  end

  test "get_map_tile_by_id/1 gets the map tile for the id", %{instance_id: instance_id} do
    assert %{id: 999} = Instances.get_map_tile_by_id(%{id: 999, map_instance_id: instance_id})
  end

  test "get_map_tile/1 gets the top map tile at the given coordinates", %{instance_id: instance_id} do
    assert %{id: 999} = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: instance_id})
  end

  test "get_map_tile/2 gets the top map tile in the given direction", %{instance_id: instance_id} do
    assert %{id: 998} = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: instance_id}, "east")
  end

  test "update_map_tile/2 updates the map tile", %{instance_id: instance_id} do
    map_tile = Instances.get_map_tile(%{id: 999, row: 1, col: 2, map_instance_id: instance_id}, nil)
    new_attributes = %{id: 333, row: 2, col: 2, character: "M"}

    assert Map.merge(map_tile, %{row: 2, col: 2, character: "M"}) == Instances.update_map_tile(map_tile, new_attributes)
  end
end

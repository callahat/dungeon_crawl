defmodule DungeonCrawl.DungeonProcesses.InstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Instances

  setup do
    instance_registry = start_supervised!(InstanceRegistry)
    map_tile =       %{id: 999, map_instance_id: 12345, row: 1, col: 2, z_index: 0, character: "B", state: "", script: ""}
    map_tile_south = %{id: 998, map_instance_id: 12345, row: 1, col: 3, z_index: 0, character: "S", state: "", script: ""}
    dungeon_map_tiles = [map_tile, map_tile_south]

    InstanceRegistry.create(instance_registry, map_tile.map_instance_id, dungeon_map_tiles)
    %{instance_registry: instance_registry}
  end

  test "get_map_tile_by_id/1 gets the map tile for the id", %{instance_registry: instance_registry} do
    assert %{id: 999} = Instances.get_map_tile_by_id(%{id: 999, map_instance_id: 12345}, instance_registry)
  end

  test "get_map_tile/1 gets the top map tile at the given coordinates", %{instance_registry: instance_registry} do
    assert %{id: 999} = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: 12345}, nil, instance_registry)
  end

  test "get_map_tile/2 gets the top map tile in the given direction", %{instance_registry: instance_registry} do
    assert %{id: 998} = Instances.get_map_tile(%{row: 1, col: 2, map_instance_id: 12345}, "east", instance_registry)
  end

  test "update_map_tile/2 updates the map tile", %{instance_registry: instance_registry} do
    map_tile = Instances.get_map_tile(%{id: 999, row: 1, col: 2, map_instance_id: 12345}, nil, instance_registry)
    new_attributes = %{id: 333, row: 2, col: 2, character: "M"}

    assert Map.merge(map_tile, %{row: 2, col: 2, character: "M"}) == Instances.update_map_tile(map_tile, new_attributes, instance_registry)
  end
end

defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry

  test "moving to an empty floor space" do
    floor_a           = %MapTile{id: 999, row: 1, col: 2, z_index: 0, character: "."}
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}

    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}
    dungeon_map_tiles = [floor_a, floor_b, player_location]

    instance_id = InstanceRegistry.create(DungeonInstanceRegistry, nil, dungeon_map_tiles)

    [player_location, floor_a] = Instances.get_map_tiles(%{map_instance_id: instance_id, row: 1, col: 2})
    destination =     Instances.get_map_tile(%{map_instance_id: instance_id, row: 1, col: 1})

    assert {:ok, %{new_location: new_location, old_location: old_location}} = Move.go(player_location, destination)
    assert %MapTile{row: 1, col: 2, character: ".", z_index: 0} = old_location

    assert %MapTile{row: 1, col: 1, z_index: 1} = new_location
    assert Instances.get_map_tiles(%{map_instance_id: instance_id, row: 1, col: 2}) == [floor_a]
    assert Instances.get_map_tiles(%{map_instance_id: instance_id, row: 1, col: 1}) == [new_location,
                                                                                        destination]
  end

  test "moving to an empty floor space from a non map tile" do
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}
    dungeon_map_tiles = [floor_b, player_location]

    instance_id = InstanceRegistry.create(DungeonInstanceRegistry, nil, dungeon_map_tiles)

    player_location = Instances.get_map_tile(%{map_instance_id: instance_id, row: 1, col: 2})
    destination =     Instances.get_map_tile(%{map_instance_id: instance_id, row: 1, col: 1})

    assert {:ok, %{new_location: new_location, old_location: old_location}} = Move.go(player_location, destination)
    assert %MapTile{id: nil,  row: 1, col: 2, character: nil} = old_location
    assert %MapTile{id: 1000, row: 1, col: 1, character: "@"} = new_location
    assert Instances.get_map_tiles(%{map_instance_id: instance_id, row: 1, col: 2}) == []
    assert Instances.get_map_tiles(%{map_instance_id: instance_id, row: 1, col: 1}) ==
             [new_location,
              destination]
  end

  test "moving to a bad space" do
    wall              = %MapTile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}
    dungeon_map_tiles = [wall, player_location]

    instance_id = InstanceRegistry.create(DungeonInstanceRegistry, nil, dungeon_map_tiles)

    player_location = Instances.get_map_tile(%{map_instance_id: instance_id, row: 1, col: 2})
    destination =     Instances.get_map_tile(%{map_instance_id: instance_id, row: 1, col: 1})

    assert {:invalid} = Move.go(player_location, destination)
  end

  test "moving to something that is not a map tile" do
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}
    dungeon_map_tiles = [player_location]

    instance_id = InstanceRegistry.create(DungeonInstanceRegistry, nil, dungeon_map_tiles)

    player_location = Instances.get_map_tile(%{map_instance_id: instance_id, row: 1, col: 2})

    assert {:invalid} = Move.go(player_location, nil)
  end
end


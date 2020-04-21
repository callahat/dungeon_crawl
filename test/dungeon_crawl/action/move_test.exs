defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances

  test "moving to an empty floor space" do
    floor_a           = %MapTile{id: 999, row: 1, col: 2, z_index: 0, character: "."}
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}

    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {floor_a, state} = Instances.create_map_tile(%Instances{}, floor_a)
    {_floor_b, state} = Instances.create_map_tile(state, floor_b)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    destination =     Instances.get_map_tile(state, %{row: 1, col: 1})

    assert {:ok, %{{1, 1} => new_location, {1, 2} => old_location}, state} = Move.go(player_location, destination, state)
    assert %MapTile{row: 1, col: 2, character: ".", z_index: 0} = old_location

    assert %MapTile{row: 1, col: 1, z_index: 1} = new_location
    assert Instances.get_map_tiles(state, %{row: 1, col: 2}) == [floor_a]
    assert Instances.get_map_tiles(state, %{row: 1, col: 1}) == [new_location,
                                                                 destination]
  end

  test "moving to an empty floor space from a non map tile" do
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {floor_b, state} = Instances.create_map_tile(%Instances{}, floor_b)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:ok, %{{1, 1} => new_location, {1, 2} => old_location}, state} = Move.go(player_location, floor_b, state)
    assert %MapTile{id: nil,  row: 1, col: 2, character: nil} = old_location
    assert %MapTile{id: 1000, row: 1, col: 1, character: "@"} = new_location
    assert Instances.get_map_tiles(state, %{row: 1, col: 2}) == []
    assert Instances.get_map_tiles(state, %{row: 1, col: 1}) ==
             [new_location,
              floor_b]
  end

  test "moving to a bad space" do
    wall              = %MapTile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {wall, state} = Instances.create_map_tile(%Instances{}, wall)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:invalid} = Move.go(player_location, wall, state)
  end

  test "moving to something that is not a map tile" do
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {player_location, state} = Instances.create_map_tile(%Instances{}, player_location)

    assert {:invalid} = Move.go(player_location, nil, state)
  end

  test "can_move/1 is true if the destination exists and is not blocking" do
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    wall              = %MapTile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}

    # Dont care about state just want the processed MapTile
    {wall, _state} = Instances.create_map_tile(%Instances{}, wall)
    {floor_b, _state} = Instances.create_map_tile(%Instances{}, floor_b)

    refute Move.can_move(nil)
    refute Move.can_move(wall)
    assert Move.can_move(floor_b)
  end
end


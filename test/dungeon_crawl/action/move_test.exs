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

  test "pushing an object" do
    floor             = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: true, blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Instances.create_map_tile(%Instances{}, floor)
    {ball, state} = Instances.create_map_tile(state, ball)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:ok, %{{1, 2} => new_location,
                   {1, 3} => old_location,
                   {1, 1} => ball_new_location},
            updated_state} = Move.go(player_location, ball, state)
    assert %MapTile{id:  nil, row: 1, col: 3, character: nil} = old_location
    assert %MapTile{id: 1000, row: 1, col: 2, character: "@"} = new_location
    assert %MapTile{id:  997, row: 1, col: 1, character: "o"} = ball_new_location
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [ball_new_location, floor]

    # Something not pushy does not push
    bullet_location   = %MapTile{id: 1001,  row: 1, col: 3, z_index: 2, character: "-", state: "not_pushy: true"}
    {bullet_location, state} = Instances.create_map_tile(state, bullet_location)
    
    assert {:invalid} = Move.go(bullet_location, ball, state)
  end

  test "pushing an object directionally wrong way" do
    floor             = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: east, blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {_floor, state} = Instances.create_map_tile(%Instances{}, floor)
    {ball, state} = Instances.create_map_tile(state, ball)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:invalid} = Move.go(player_location, ball, state)
  end

  test "pushing a line of objects" do
    floor             = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}
    floor2             = %MapTile{id: 994, row: 1, col: 0, z_index: 0, character: ".", state: "blocking: false"}
    ball2              = %MapTile{id: 995, row: 1, col: 1, z_index: 1, character: "o", state: "pushable: true"}

    {floor, state} = Instances.create_map_tile(%Instances{}, floor)
    {ball, state} = Instances.create_map_tile(state, ball)
    {player_location, state} = Instances.create_map_tile(state, player_location)
    {floor2, state} = Instances.create_map_tile(state, floor2)
    {_ball2, state} = Instances.create_map_tile(state, ball2)

    assert {:ok, %{{1, 2} => new_location,
                   {1, 3} => old_location,
                   {1, 1} => ball_new_location,
                   {1, 0} => ball2_new_location},
            updated_state} = Move.go(player_location, ball, state)

    assert %MapTile{id:  nil, row: 1, col: 3, character: nil} = old_location
    assert %MapTile{id: 1000, row: 1, col: 2, character: "@"} = new_location
    assert %MapTile{id:  997, row: 1, col: 1, character: "o"} = ball_new_location
    assert %MapTile{id:  995, row: 1, col: 0, character: "o"} = ball2_new_location
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [ball_new_location, floor]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 0}) == [ball2_new_location, floor2]

    # cannot push into blocking
    wall            = %MapTile{id: 1001, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
    {_wall, state} = Instances.create_map_tile(state, wall)

    assert {:invalid} = Move.go(player_location, ball, state)
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


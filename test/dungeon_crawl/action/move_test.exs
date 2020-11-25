defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])
    %{state: InstanceProcess.get_state(instance_process)}
  end

  test "moving to an empty floor space", %{state: state} do
    floor_a           = %MapTile{id: 999, row: 1, col: 2, z_index: 0, character: "."}
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}

    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {floor_a, state} = Instances.create_map_tile(state, floor_a)
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

  test "moving to an empty floor space from a non map tile", %{state: state} do
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {floor_b, state} = Instances.create_map_tile(state, floor_b)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:ok, %{{1, 1} => new_location, {1, 2} => old_location}, state} = Move.go(player_location, floor_b, state)
    assert %MapTile{id: nil,  row: 1, col: 2, character: nil} = old_location
    assert %MapTile{id: 1000, row: 1, col: 1, character: "@"} = new_location
    assert Instances.get_map_tiles(state, %{row: 1, col: 2}) == []
    assert Instances.get_map_tiles(state, %{row: 1, col: 1}) ==
             [new_location,
              floor_b]
  end

  test "moving to a bad space", %{state: state} do
    wall              = %MapTile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {wall, state} = Instances.create_map_tile(state, wall)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:invalid} = Move.go(player_location, wall, state)
  end

  test "moving to a teleporter", %{state: state} do
    floor_a      = %MapTile{id: 990, row: 1, col: 1, z_index: 0, character: "."}
    teleporter_e = %MapTile{id: 991, row: 1, col: 2, z_index: 0, character: ">", state: "teleporter: true, facing: east, blocking: true"}
    floor_b      = %MapTile{id: 992, row: 1, col: 3, z_index: 0, character: "."}
    wall_b       = %MapTile{id: 993, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
    teleporter_w = %MapTile{id: 994, row: 1, col: 4, z_index: 0, character: "<", state: "teleporter: true, facing: west, blocking: true"}
    floor_c      = %MapTile{id: 995, row: 1, col: 5, z_index: 0, character: "."}
    wall_c       = %MapTile{id: 996, row: 1, col: 5, z_index: 1, character: "#", state: "blocking: true"}

    player_location   = %MapTile{id: 9000,  row: 1, col: 1, z_index: 1, character: "@"}

    {floor_a, state} =      Instances.create_map_tile(%{ state | state_values: %{rows: 7, cols: 7}}, floor_a)
    {teleporter_e, state} = Instances.create_map_tile(state, teleporter_e)
    {floor_b, state} =      Instances.create_map_tile(state, floor_b)
    {wall_b, state} =       Instances.create_map_tile(state, wall_b)
    {_teleporter_w, state} = Instances.create_map_tile(state, teleporter_w)
    {floor_c, state} =      Instances.create_map_tile(state, floor_c)
    {wall_c, state} =       Instances.create_map_tile(state, wall_c)

    {player_location, state} = Instances.create_map_tile(state, player_location)

    # cannot move when teleporter exits are blocked
    assert {:invalid} = Move.go(player_location, teleporter_e, state)

    # teleports to the nearest available teleport exit
    {_, state} = Instances.delete_map_tile(state, wall_c, false)

    assert {:ok, %{{1, 5} => new_location, {1, 1} => old_location}, updated_state} = Move.go(player_location, teleporter_e, state)
    assert %MapTile{row: 1, col: 1, character: ".", z_index: 0} = old_location

    assert %MapTile{row: 1, col: 5, z_index: 1} = new_location
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [floor_a]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 5}) == [new_location,
                                                                         floor_c]

    # right past the teleporter counts as nearest available when its available
    {_, state} = Instances.delete_map_tile(state, wall_b, false)

    assert {:ok, %{{1, 3} => new_location, {1, 1} => old_location}, updated_state} = Move.go(player_location, teleporter_e, state)
    assert %MapTile{row: 1, col: 1, character: ".", z_index: 0} = old_location

    assert %MapTile{row: 1, col: 3, z_index: 1} = new_location
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [floor_a]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == [new_location,
                                                                         floor_b]

    # cannot use teleporter if coming from the side
    {player_location, state} = Instances.update_map_tile(state, player_location, %{row: 2, col: 2})
    assert {:invalid} = Move.go(player_location, teleporter_e, state)

    # can push objects through teleporter
    {player_location, state} = Instances.update_map_tile(state, player_location, %{row: 1, col: 0})
    ball = %MapTile{id: 800, row: 1, col: 1, z_index: 1, character: "o", state: "blocking: true, pushable: true"}
    {ball, state} =       Instances.create_map_tile(state, ball)

    assert {:ok, %{{1, 1} => new_location, {1, 0} => old_location, {1, 3} => pushed_location}, updated_state} =
      Move.go(player_location, ball, state)
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 0}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [new_location,
                                                                         floor_a]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == [pushed_location,
                                                                         floor_b]
  end

  test "pushing an object", %{state: state} do
    floor             = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: true, blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Instances.create_map_tile(state, floor)
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

    # Something not pushing does not push
    bullet_location   = %MapTile{id: 1001,  row: 1, col: 3, z_index: 2, character: "-", state: "not_pushing: true"}
    {bullet_location, state} = Instances.create_map_tile(state, bullet_location)

    assert {:invalid} = Move.go(bullet_location, ball, state)
  end

  test "pushing an object directionally wrong way", %{state: state} do
    floor             = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: east, blocking: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {_floor, state} = Instances.create_map_tile(state, floor)
    {ball, state} = Instances.create_map_tile(state, ball)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:invalid} = Move.go(player_location, ball, state)
  end

  test "pushing a line of objects", %{state: state} do
    floor             = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: true"}
    player_location   = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}
    floor2             = %MapTile{id: 994, row: 1, col: 0, z_index: 0, character: ".", state: "blocking: false"}
    ball2              = %MapTile{id: 995, row: 1, col: 1, z_index: 1, character: "o", state: "pushable: true"}

    {floor, state} = Instances.create_map_tile(state, floor)
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

  test "a squishable object", %{state: state} do
    floor           = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    balloon         = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "squishable: true"}
    player_location = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Instances.create_map_tile(state, floor)
    {balloon, state} = Instances.create_map_tile(state, balloon)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    # squishable object is gone
    assert {:ok, %{{1, 2} => new_location,
                   {1, 3} => old_location},
            updated_state} = Move.go(player_location, balloon, state)
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [floor]

    # Something not squishing does not squish
    bullet_location   = %MapTile{id: 1001,  row: 1, col: 3, z_index: 2, character: "-", state: "not_squishing: true"}
    {bullet_location, state} = Instances.create_map_tile(state, bullet_location)

    assert {:ok, %{{1, 2} => new_bullet_location,
                   {1, 3} => old_bullet_location},
            updated_state} = Move.go(bullet_location, balloon, state)
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 2}) == [new_bullet_location, balloon]
  end

  test "a squishable pushable object", %{state: state} do
    floor           = %MapTile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    balloon         = %MapTile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "squishable: true, pushable: true"}
    player_location = %MapTile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Instances.create_map_tile(state, floor)
    {balloon, state} = Instances.create_map_tile(state, balloon)
    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:ok, %{{1, 1} => new_balloon_location,
                   {1, 2} => new_location,
                   {1, 3} => old_location},
            updated_state} = Move.go(player_location, balloon, state)
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [new_balloon_location, floor]

    # with no place to be pushed, the object is squashed (deleted)
    assert {:ok, %{{1, 1} => new_location,
                   {1, 2} => old_location},
            updated_state} = Move.go(new_location, new_balloon_location, updated_state)
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 2}) == []
    assert Instances.get_map_tiles(updated_state, %{row: 1, col: 1}) == [new_location, floor]
  end

  test "moving to something that is not a map tile", %{state: state} do
    player_location   = %MapTile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {player_location, state} = Instances.create_map_tile(state, player_location)

    assert {:invalid} = Move.go(player_location, nil, state)
  end

  test "can_move/1 is true if the destination exists and is not blocking", %{state: state} do
    floor_b           = %MapTile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    wall              = %MapTile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}

    # Dont care about state just want the processed MapTile
    {wall, _state} = Instances.create_map_tile(state, wall)
    {floor_b, _state} = Instances.create_map_tile(state, floor_b)

    refute Move.can_move(nil)
    refute Move.can_move(wall)
    assert Move.can_move(floor_b)
  end
end


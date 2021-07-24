defmodule DungeonCrawl.Action.MoveTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels

  test "moving to an empty floor space" do
    floor_a           = %Tile{id: 999, row: 1, col: 2, z_index: 0, character: "."}
    floor_b           = %Tile{id: 998, row: 1, col: 1, z_index: 0, character: "."}

    player_location   = %Tile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@", state: "player: true"}

    {floor_a, state} = Levels.create_tile(%Levels{}, floor_a)
    {_floor_b, state} = Levels.create_tile(state, floor_b)
    {player_location, state} = Levels.create_tile(state, player_location)

    destination =     Levels.get_tile(state, %{row: 1, col: 1})

    assert {:ok, %{{1, 1} => new_location, {1, 2} => old_location}, state} = Move.go(player_location, destination, state)
    assert %Tile{row: 1, col: 2, character: ".", z_index: 0} = old_location

    assert %Tile{row: 1, col: 1, z_index: 1} = new_location
    assert Levels.get_tiles(state, %{row: 1, col: 2}) == [floor_a]
    assert Levels.get_tiles(state, %{row: 1, col: 1}) == [new_location,
                                                                 destination]
    assert new_location.parsed_state[:steps] == 1
  end

  test "moving to an empty floor space from a non tile" do
    floor_b           = %Tile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    player_location   = %Tile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {floor_b, state} = Levels.create_tile(%Levels{}, floor_b)
    {player_location, state} = Levels.create_tile(state, player_location)

    assert {:ok, %{{1, 1} => new_location, {1, 2} => old_location}, state} = Move.go(player_location, floor_b, state)
    assert %Tile{id: nil,  row: 1, col: 2, character: nil} = old_location
    assert %Tile{id: 1000, row: 1, col: 1, character: "@"} = new_location
    assert Levels.get_tiles(state, %{row: 1, col: 2}) == []
    assert Levels.get_tiles(state, %{row: 1, col: 1}) ==
             [new_location,
              floor_b]
  end

  test "moving to a bad space" do
    wall              = %Tile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}
    player_location   = %Tile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {wall, state} = Levels.create_tile(%Levels{}, wall)
    {player_location, state} = Levels.create_tile(state, player_location)
    program_messages = [{997, "touch", %{name: nil, parsed_state: %{}, tile_id: 1000}}]
    assert {:invalid, %{}, Map.put(state, :program_messages, program_messages)} == Move.go(player_location, wall, state)
  end

  test "moving to a teleporter" do
    floor_a      = %Tile{id: 990, row: 1, col: 1, z_index: 0, character: "."}
    teleporter_e = %Tile{id: 991, row: 1, col: 2, z_index: 0, character: ">", state: "teleporter: true, facing: east, blocking: true"}
    floor_b      = %Tile{id: 992, row: 1, col: 3, z_index: 0, character: "."}
    wall_b       = %Tile{id: 993, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
    teleporter_w = %Tile{id: 994, row: 1, col: 4, z_index: 0, character: "<", state: "teleporter: true, facing: west, blocking: true"}
    floor_c      = %Tile{id: 995, row: 1, col: 5, z_index: 0, character: "."}
    wall_c       = %Tile{id: 996, row: 1, col: 5, z_index: 1, character: "#", state: "blocking: true"}

    player_location   = %Tile{id: 9000,  row: 1, col: 1, z_index: 1, character: "@", state: "already_touched: false"}

    {floor_a, state} =      Levels.create_tile(%Levels{state_values: %{rows: 7, cols: 7}}, floor_a)
    {teleporter_e, state} = Levels.create_tile(state, teleporter_e)
    {floor_b, state} =      Levels.create_tile(state, floor_b)
    {wall_b, state} =       Levels.create_tile(state, wall_b)
    {_teleporter_w, state} = Levels.create_tile(state, teleporter_w)
    {floor_c, state} =      Levels.create_tile(state, floor_c)
    {wall_c, state} =       Levels.create_tile(state, wall_c)

    {player_location, state} = Levels.create_tile(state, player_location)

    # cannot move when teleporter exits are blocked
    program_messages = [{991, "touch", %{name: nil, parsed_state: %{already_touched: false}, tile_id: 9000}}]
    assert {:invalid, tile_changes, expected_updated_state} = Move.go(player_location, teleporter_e, state)
    assert tile_changes == %{}
    assert %{ state | program_messages: program_messages, dirty_ids: %{}} == %{ expected_updated_state | dirty_ids: %{}}

    # teleports to the nearest available teleport exit
    {_, state} = Levels.delete_tile(state, wall_c, false)

    assert {:ok, %{{1, 5} => new_location, {1, 1} => old_location}, updated_state} = Move.go(player_location, teleporter_e, state)
    assert %Tile{row: 1, col: 1, character: ".", z_index: 0} = old_location

    assert %Tile{row: 1, col: 5, z_index: 1} = new_location
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [floor_a]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 5}) == [new_location,
                                                                         floor_c]

    # right past the teleporter counts as nearest available when its available
    {_, state} = Levels.delete_tile(state, wall_b, false)

    assert {:ok, %{{1, 3} => new_location, {1, 1} => old_location}, updated_state} = Move.go(player_location, teleporter_e, state)
    assert %Tile{row: 1, col: 1, character: ".", z_index: 0} = old_location

    assert %Tile{row: 1, col: 3, z_index: 1} = new_location
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [floor_a]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == [new_location,
                                                                         floor_b]

    # cannot use teleporter if coming from the side
    {player_location, state} = Levels.update_tile(state, player_location, %{row: 2, col: 2})
    program_messages = [{991, "touch", %{name: nil, parsed_state: %{already_touched: false}, tile_id: 9000}}]
    assert {:invalid, tile_changes, expected_updated_state} = Move.go(player_location, teleporter_e, state)
    assert tile_changes == %{}
    assert %{ state | program_messages: program_messages, dirty_ids: %{}} == %{ expected_updated_state | dirty_ids: %{}}

    # can push objects through teleporter
    {player_location, state} = Levels.update_tile(state, player_location, %{row: 1, col: 0})
    ball = %Tile{id: 800, row: 1, col: 1, z_index: 1, character: "o", state: "blocking: true, pushable: true"}
    {ball, state} =       Levels.create_tile(state, ball)

    assert {:ok, %{{1, 1} => new_location, {1, 0} => _old_location, {1, 3} => pushed_location}, updated_state} =
      Move.go(player_location, ball, state)
    assert Levels.get_tiles(updated_state, %{row: 1, col: 0}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [new_location,
                                                                         floor_a]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == [pushed_location,
                                                                         floor_b]
  end

  test "pushing an object" do
    floor             = %Tile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %Tile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: true, blocking: true"}
    player_location   = %Tile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Levels.create_tile(%Levels{}, floor)
    {ball, state} = Levels.create_tile(state, ball)
    {player_location, state} = Levels.create_tile(state, player_location)

    assert {:ok, %{{1, 2} => new_location,
                   {1, 3} => old_location,
                   {1, 1} => ball_new_location},
            updated_state} = Move.go(player_location, ball, state)
    assert %Tile{id:  nil, row: 1, col: 3, character: nil} = old_location
    assert %Tile{id: 1000, row: 1, col: 2, character: "@"} = new_location
    assert %Tile{id:  997, row: 1, col: 1, character: "o"} = ball_new_location
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [ball_new_location, floor]

    # Something not pushing does not push
    bullet_location   = %Tile{id: 1001,  row: 1, col: 3, z_index: 2, character: "-", state: "not_pushing: true"}
    {bullet_location, state} = Levels.create_tile(state, bullet_location)

    program_messages = [{997, "touch", %{name: nil, parsed_state: %{not_pushing: true}, tile_id: 1001}}]
    assert {:invalid, %{}, Map.put(state, :program_messages, program_messages)} == Move.go(bullet_location, ball, state)
  end

  test "pushing an object directionally wrong way" do
    floor             = %Tile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %Tile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: east, blocking: true"}
    player_location   = %Tile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {_floor, state} = Levels.create_tile(%Levels{}, floor)
    {ball, state} = Levels.create_tile(state, ball)
    {player_location, state} = Levels.create_tile(state, player_location)

    program_messages = [{997, "touch", %{name: nil, parsed_state: %{}, tile_id: 1000}}]
    assert {:invalid, %{}, Map.put(state, :program_messages, program_messages)} == Move.go(player_location, ball, state)
  end

  test "pushing a line of objects" do
    floor             = %Tile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    ball              = %Tile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "pushable: true"}
    player_location   = %Tile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}
    floor2             = %Tile{id: 994, row: 1, col: 0, z_index: 0, character: ".", state: "blocking: false"}
    ball2              = %Tile{id: 995, row: 1, col: 1, z_index: 1, character: "o", state: "pushable: true"}

    {floor, state} = Levels.create_tile(%Levels{}, floor)
    {ball, state} = Levels.create_tile(state, ball)
    {player_location, state} = Levels.create_tile(state, player_location)
    {floor2, state} = Levels.create_tile(state, floor2)
    {_ball2, state} = Levels.create_tile(state, ball2)

    assert {:ok, %{{1, 2} => new_location,
                   {1, 3} => old_location,
                   {1, 1} => ball_new_location,
                   {1, 0} => ball2_new_location},
            updated_state} = Move.go(player_location, ball, state)

    assert %Tile{id:  nil, row: 1, col: 3, character: nil} = old_location
    assert %Tile{id: 1000, row: 1, col: 2, character: "@"} = new_location
    assert %Tile{id:  997, row: 1, col: 1, character: "o"} = ball_new_location
    assert %Tile{id:  995, row: 1, col: 0, character: "o"} = ball2_new_location
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [ball_new_location, floor]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 0}) == [ball2_new_location, floor2]

    # cannot push into blocking
    wall            = %Tile{id: 1001, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
    {_wall, state} = Levels.create_tile(state, wall)

    program_messages = [{997, "touch", %{name: nil, parsed_state: %{}, tile_id: 1000}}]
    assert {:invalid, %{}, Map.put(state, :program_messages, program_messages)} == Move.go(player_location, ball, state)
  end

  test "a squishable object" do
    floor           = %Tile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    balloon         = %Tile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "squishable: true"}
    player_location = %Tile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Levels.create_tile(%Levels{}, floor)
    {balloon, state} = Levels.create_tile(state, balloon)
    {player_location, state} = Levels.create_tile(state, player_location)

    # squishable object is gone
    assert {:ok, %{{1, 2} => new_location,
                   {1, 3} => _old_location},
            updated_state} = Move.go(player_location, balloon, state)
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [floor]

    # Something not squishing does not squish
    bullet_location   = %Tile{id: 1001,  row: 1, col: 3, z_index: 2, character: "-", state: "not_squishing: true"}
    {bullet_location, state} = Levels.create_tile(state, bullet_location)

    assert {:ok, %{{1, 2} => new_bullet_location,
                   {1, 3} => _old_bullet_location},
            updated_state} = Move.go(bullet_location, balloon, state)
    assert Levels.get_tiles(updated_state, %{row: 1, col: 2}) == [new_bullet_location, balloon]
  end

  test "a squishable pushable object" do
    floor           = %Tile{id: 996, row: 1, col: 1, z_index: 0, character: ".", state: "blocking: false"}
    balloon         = %Tile{id: 997, row: 1, col: 2, z_index: 1, character: "o", state: "squishable: true, pushable: true"}
    player_location = %Tile{id: 1000,  row: 1, col: 3, z_index: 1, character: "@"}

    {floor, state} = Levels.create_tile(%Levels{}, floor)
    {balloon, state} = Levels.create_tile(state, balloon)
    {player_location, state} = Levels.create_tile(state, player_location)

    assert {:ok, %{{1, 1} => new_balloon_location,
                   {1, 2} => new_location,
                   {1, 3} => _old_location},
            updated_state} = Move.go(player_location, balloon, state)
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 2}) == [new_location]
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [new_balloon_location, floor]

    # with no place to be pushed, the object is squashed (deleted)
    assert {:ok, %{{1, 1} => new_location,
                   {1, 2} => _old_location},
            updated_state} = Move.go(new_location, new_balloon_location, updated_state)
    assert Levels.get_tiles(updated_state, %{row: 1, col: 3}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 2}) == []
    assert Levels.get_tiles(updated_state, %{row: 1, col: 1}) == [new_location, floor]
  end

  test "moving to something that is not a tile" do
    player_location   = %Tile{id: 1000,  row: 1, col: 2, z_index: 1, character: "@"}

    {player_location, state} = Levels.create_tile(%Levels{}, player_location)

    assert {:invalid, %{}, ^state} = Move.go(player_location, nil, state)
  end

  test "can_move/1 is true if the destination exists and is not blocking" do
    floor_b           = %Tile{id: 998, row: 1, col: 1, z_index: 0, character: "."}
    wall              = %Tile{id: 997, row: 1, col: 1, z_index: 0, character: "#", state: "blocking: true"}

    # Dont care about state just want the processed Tile
    {wall, _state} = Levels.create_tile(%Levels{}, wall)
    {floor_b, _state} = Levels.create_tile(%Levels{}, floor_b)

    refute Move.can_move(nil)
    refute Move.can_move(wall)
    assert Move.can_move(floor_b)
  end
end


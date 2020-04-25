defmodule DungeonCrawl.Scripting.CommandTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonProcesses.Instances

  def program_fixture(script \\ nil) do
    script = script ||
             """
             #END
             No show this text
             :TOUCH
             testing
             #END
             """
    {:ok, program} = Parser.parse(script)
    program
  end

  test "get_command/1" do
    assert Command.get_command(" BECOME  ") == :become
    assert Command.get_command(:become) == :become
    assert Command.get_command(:change_state) == :change_state
    assert Command.get_command(:cycle) == :cycle
    assert Command.get_command(:die) == :die
    assert Command.get_command(:end) == :halt    # exception to the naming convention, cant "def end do"
    assert Command.get_command(:go) == :go
    assert Command.get_command(:if) == :jump_if
    assert Command.get_command(:lock) == :lock
    assert Command.get_command(:move) == :move
    assert Command.get_command(:noop) == :noop
    assert Command.get_command(:text) == :text
    assert Command.get_command(:try) == :try
    assert Command.get_command(:unlock) == :unlock
    assert Command.get_command(:restore) == :restore
    assert Command.get_command(:walk) == :walk
    assert Command.get_command(:zap) == :zap

    refute Command.get_command(:fake_not_real)
  end

  test "BECOME" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()
    params = [%{character: "~", color: "puce"}]

    %Runner{state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert Map.take(updated_map_tile, [:character, :color]) == %{character: "~", color: "puce"}
  end

  test "BECOME a ttid" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()
    squeaky_door = insert_tile_template(%{script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true"})
    params = [{:ttid, squeaky_door.id}]

    %Runner{program: program, state: state} = Command.become(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)

    refute Map.take(updated_map_tile, [:state]) == %{script: map_tile.state}
    refute Map.take(updated_map_tile, [:parsed_state]) == %{script: map_tile.parsed_state}
    refute Map.take(updated_map_tile, [:script]) == %{script: map_tile.script}
    assert Map.take(updated_map_tile, [:character, :color, :script]) == Map.take(squeaky_door, [:character, :color, :script])
    assert program.status == :idle
    assert %{1 => [:halt, [""]],
             2 => [:noop, "TOUCH"],
             3 => [:text, ["SQUEEEEEEEEEK"]]} = program.instructions
    assert %{blocking: true} = updated_map_tile.parsed_state
  end

  test "CHANGE_STATE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: "one: 100, add: 8"})
    program = program_fixture()

    %Runner{state: updated_state} = Command.change_state(%Runner{program: program, object_id: map_tile.id, state: state}, [:add, "+=", 1])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "add: 9, one: 100"
    %Runner{state: updated_state} = Command.change_state(%Runner{program: program, object_id: map_tile.id, state: state}, [:one, "=", 432])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "add: 8, one: 432"
    %Runner{state: updated_state} = Command.change_state(%Runner{program: program, object_id: map_tile.id, state: state}, [:new, "+=", 1])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "add: 8, new: 1, one: 100"
  end

  test "CYCLE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.cycle(%Runner{program: program, object_id: map_tile.id, state: state}, [3])
    map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert map_tile.state == "wait_cycles: 3"
    %Runner{state: state} = Command.cycle(%Runner{program: program, object_id: map_tile.id, state: state}, [-2])
    map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert map_tile.state == "wait_cycles: 3"
    %Runner{state: state} = Command.cycle(%Runner{program: program, object_id: map_tile.id, state: state}, [1])
    map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert map_tile.state == "wait_cycles: 1"
  end

  test "COMPOUND_MOVE" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    # Successful
    %Runner{program: program, state: state} = Command.compound_move(%Runner{object_id: mover.id, state: state},
                                                                    [{"west", true}, {"east", true}])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [[
                  "tile_changes",
                  %{
                    tiles: [
                      %{col: 1, rendering: "<div>c</div>", row: 1},
                      %{col: 2, rendering: "<div>.</div>", row: 1}
                    ]
                  }
                ]],
             pc: 0,
             lc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful (but its a try and move that does not keep trying)
    %Runner{program: program, state: state} = Command.compound_move(%Runner{object_id: mover.id, state: state},
                                                                    [{"south", false}])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful (but its a retry until successful)
    %Runner{program: program, state: state} = Command.compound_move(%Runner{object_id: mover.id, state: state},
                                                                    [{"south", true}, {"east", true}])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 0
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Last movement already done
    runner_state = %Runner{object_id: mover.id, state: state, program: %Program{ status: :alive, lc: 2 }}
    %Runner{program: program} = Command.compound_move(runner_state, [{"idle", true}, {"east", true}])
    assert %{status: :alive,
             wait_cycles: 0,
             broadcasts: [],
             pc: 1,
             lc: 0
           } = program
  end

  test "COMPOUND_MOVE into something blocking (or a nil square) triggers a THUD event" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    program = program_fixture("""
                              /s/w?e?e
                              #END
                              #END
                              :THUD
                              #BECOME character: X
                              """)

    %Runner{program: program} = Command.compound_move(%Runner{program: program, object_id: mover.id, state: state}, [{"south", true}])

    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 4,
             lc: 0
           } = program
  end

  test "DIE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 1, character: "$"})
    {under_tile, state} = Instances.create_map_tile(state, %MapTile{id: 45, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{program: program, state: state} = Command.die(%Runner{program: program, object_id: map_tile.id, state: state})
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert under_tile == Instances.get_map_tile(state, map_tile)
    assert program.status == :dead
    assert program.pc == -1
    refute updated_map_tile
    assert [ ["tile_changes",
              %{tiles: [%{col: 2, rendering: "<div>.</div>", row: 1}]}
              ]
           ] = program.broadcasts
  end

  test "GO" do
    # Basically Move with true
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    assert Command.go(%Runner{object_id: mover.id, state: state}, ["left"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["left", true])

    # Unsuccessful
    assert Command.go(%Runner{object_id: mover.id, state: state}, ["down"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["down", true])
  end

  test "HALT/END" do
    program = program_fixture()
#    stubbed_object = %{id: 1, state: ""}
#    stubbed_state = %{map_by_ids: %{1 => stubbed_object}}

    %Runner{program: program} = Command.halt(%Runner{program: program})
    assert program.status == :idle
    assert program.pc == -1
  end

  test "FACING" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: "facing: up"})
    program = program_fixture()

    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["east"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: east"
    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["clockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: east"
    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["counterclockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: west"
    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["reverse"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: south"
    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["player"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: idle, target_player_map_tile_id: nil"

    # Facing to player direction targets that player when it is not targeting a player
    {fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"}, %Location{})
    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["player"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: south, target_player_map_tile_id: 43201"

    # Facing to player direction when there is no players sets facing to idle and the target player to nil
    {_fake_player, state} = Instances.delete_map_tile(state, fake_player)
    %Runner{state: updated_state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["player"])
    updated_map_tile = Instances.get_map_tile_by_id(updated_state, map_tile)
    assert updated_map_tile.state == "facing: idle, target_player_map_tile_id: nil"
  end

  test "FACING - derivative when facing state var does not exist" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["clockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["counterclockwise"])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: map_tile.id, state: state}, ["reverse"])
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile.state == "facing: idle"
  end

  test "JUMP_IF when state check is TRUE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true"})
    program = program_fixture()
#    map_tile = %{id: 1, state: "thing: true", parsed_state: %{thing: true}}
#    state = %Instances{map_by_ids: %{1 => stubbed_object}}
    params = [[:state_variable, :thing], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3

    # with explicit check
    params = [[:state_variable, :thing, "==", true], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3
  end

  test "JUMP_IF when state check is FALSE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true"})
    program = program_fixture()
#    stubbed_object = %{state: "thing: true", parsed_state: %{thing: true}}
    params = [["!", :check_state, :thing], "TOUCH"]

    assert program.status == :alive
    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1

    # with explicit check
    params = [["!", :check_state, :thing, "==", true], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1
  end

  test "JUMP_IF when state check is TRUE but no active label" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, state: "thing: true"})
    program = program_fixture()
#    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing], "TOUCH"]

    program = %{ program | labels: %{"TOUCH" => [[3, false]]} }
    %Runner{program: program} = Command.jump_if(%Runner{program: program, object_id: map_tile.id, state: state}, params)
    assert program.status == :alive
    assert program.pc == 1
  end

  test "LOCK" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.lock(%Runner{program: program, object_id: map_tile.id, state: state}, [])
    map_tile = Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "locked: true"
    assert map_tile.parsed_state == %{locked: true}
  end

  test "MOVE with one param" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 4, character: "#", row: 0, col: 1, z_index: 0, state: "blocking: true"})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    # Successful
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["left"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [[
                  "tile_changes",
                  %{
                    tiles: [
                      %{col: 1, rendering: "<div>c</div>", row: 1},
                      %{col: 2, rendering: "<div>.</div>", row: 1}
                    ]
                  }
                ]],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [{1, "touch", %{map_tile_id: 3}}] = state.program_messages
    state = %{state | program_messages: []}

    # Unsuccessful (but its a try and move that does not keep trying)
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["down"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [] = state.program_messages
    state = %{state | program_messages: []}

    # Unsuccessful - uses the wait cycles from the state
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["up"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [{4, "touch", %{map_tile_id: 3}}] = state.program_messages
    state = %{state | program_messages: []}

    # Idle
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["idle"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [] = state.program_messages

    # Moving in player direction targets a player when it is not targeting a player
    {fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"}, %Location{})
    %Runner{state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{row: 1,
             col: 2,
             character: "c",
             state: "facing: east, target_player_map_tile_id: 43201",
             z_index: 1} = mover

    # Moving in player direction keeps after that player
    {another_fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43215, row: 1, col: 5, z_index: 0, character: "@"}, %Location{})
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: south, target_player_map_tile_id: 43201",
             z_index: 1} = mover

    # When target player leaves dungeon, another target is chosen 
    {_, state} = Instances.delete_map_tile(state, fake_player)
    %Runner{state: state} = Command.facing(%Runner{program: program, object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: north, target_player_map_tile_id: 43215",
             z_index: 1} = mover
    {_, state} = Instances.delete_map_tile(state, another_fake_player)

    # Move towards player (will end up being unchanged since no players remaining)
    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["player"])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: north, target_player_map_tile_id: nil",
             z_index: 1} = mover
  end

  test "MOVE with two params" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, ["left", true])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [[
                  "tile_changes",
                  %{
                    tiles: [
                      %{col: 1, rendering: "<div>c</div>", row: 1},
                      %{col: 2, rendering: "<div>.</div>", row: 1}
                    ]
                  }
                ]],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful
    %Runner{program: program, state: _state} = Command.move(%Runner{object_id: mover.id, state: state}, ["down", true])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0 # decremented so when runner increments the PC it will still be the current move command
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
  end

  test "MOVE using a state variable" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1, state: "facing: west"})

    %Runner{program: program, state: state} = Command.move(%Runner{object_id: mover.id, state: state}, [[:state_variable, :facing], true])
    mover = Instances.get_map_tile_by_id(state, mover)
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [[
                  "tile_changes",
                  %{
                    tiles: [
                      %{col: 1, rendering: "<div>c</div>", row: 1},
                      %{col: 2, rendering: "<div>.</div>", row: 1}
                    ]
                  }
                ]],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
  end

  test "MOVE into something blocking (or a nil square) triggers a THUD event" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    program = program_fixture("""
                              #MOVE south
                              #END
                              #END
                              :THUD
                              #BECOME character: X
                              """)

    %Runner{program: program} = Command.move(%Runner{program: program, object_id: mover.id, state: state}, ["south", true])

    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 4
           } = program
  end

  test "NOOP" do
    program = program_fixture()
    stubbed_object = %{id: 1, state: "thing: true"}
    stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object } }
    runner_state = %Runner{object_id: stubbed_object.id, program: program, state: stubbed_state}
    assert runner_state == Command.noop(runner_state)
  end

  test "RESTORE" do
    program = %Program{ labels: %{"thud" => [[1, false], [5, false], [9, true]]} }

    runner_state = Command.restore(%Runner{program: program}, ["thud"])
    assert %{"thud" => [[1,false], [5,true], [9,true]]} == runner_state.program.labels

    runner_state = Command.restore(%{ runner_state | program: runner_state.program}, ["thud"])
    assert %{"thud" => [[1,true], [5,true], [9,true]]} == runner_state.program.labels

    assert runner_state == Command.restore(runner_state, ["thud"])
    assert runner_state == Command.restore(runner_state, ["derp"])
  end

  test "SEND message to self" do
    program = program_fixture()
    stubbed_object = %MapTile{id: 1337}
    state = %Instances{map_by_ids: %{1337 => stubbed_object}}
    stubbed_id = %{map_tile_id: stubbed_object.id}

    %Runner{state: state} = Command.send_message(%Runner{program: program, object_id: stubbed_object.id, state: state}, ["touch"])
    assert state.program_messages == [{1337, "touch", stubbed_id}]

    # program_messages has more recent messages at the front of the list
    %Runner{state: state} = Command.send_message(%Runner{program: program, object_id: stubbed_object.id, state: state}, ["tap", "self"])
    assert state.program_messages == [{1337, "tap", stubbed_id}, {1337, "touch", stubbed_id}]
  end

  test "SEND message to event sender" do
    sender = %{map_tile_id: 9001}
    stubbed_object = %MapTile{id: 1337}
    state = %Instances{map_by_ids: %{1337 => stubbed_object}}
    stubbed_id = %{map_tile_id: stubbed_object.id}

    %Runner{state: state} = Command.send_message(%Runner{object_id: stubbed_object.id, event_sender: sender, state: state}, ["touch", [:event_sender]])
    assert state.program_messages == [{9001, "touch", stubbed_id}]

    # program_messages has more recent messages at the front of the list
    %Runner{state: state} = Command.send_message(%Runner{state: state, object_id: stubbed_object.id, event_sender: sender}, ["tap", [:event_sender]])
    assert state.program_messages == [{9001, "tap", stubbed_id}, {9001, "touch", stubbed_id}]
  end

  test "SEND message to others" do
    program = program_fixture()
    stubbed_object = %MapTile{id: 1337}
    stubbed_id = %{map_tile_id: stubbed_object.id}
    state = %Instances{program_contexts: %{1337 => %Program{}, 55 => %Program{}, 1 => %Program{}, 9001 => %Program{}}, map_by_ids: %{1337 => stubbed_object}}

    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object_id: stubbed_object.id}, ["tap", "others"])
    assert state.program_messages == [{9001, "tap", stubbed_id}, {55, "tap", stubbed_id}, {1, "tap", stubbed_id}]
  end

  test "SEND message to all" do
    program = program_fixture()
    stubbed_object = %MapTile{id: 1337}
    stubbed_id = %{map_tile_id: stubbed_object.id}
    state = %Instances{program_contexts: %{1337 => %Program{}, 55 => %Program{}, 1 => %Program{}, 9001 => %Program{}}, map_by_ids: %{1337 => stubbed_object}}

    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object_id: stubbed_object.id}, ["dance", "all"])
    assert state.program_messages == [{9001, "dance", stubbed_id}, {1337, "dance", stubbed_id}, {55, "dance", stubbed_id}, {1, "dance", stubbed_id}]
  end

  test "SEND message to tiles in a direction" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "c", row: 2, col: 2, z_index: 0, state: "facing: north"})
    obj_id = %{map_tile_id: obj.id}

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", "north"])
    assert updated_state.program_messages == [{123, "touch", obj_id}, {255, "touch", obj_id}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", "south"])
    assert updated_state.program_messages == [{999, "touch", obj_id}]

    # Also works if the direction is in a state variable
    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", [:state_variable, :facing]])
    assert updated_state.program_messages == [{123, "touch", obj_id}, {255, "touch", obj_id}]

    # Doesnt break if nonexistant state var
    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["touch", [:state_variable, :fake]])
    assert updated_state.program_messages == []
  end

  test "SEND message to tiles by name" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  name: "A", character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  name: "A", character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  name: "C", character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, name: nil, character: "c", row: 2, col: 2, z_index: 0})
    obj_id = %{map_tile_id: obj.id}

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["name", "a"])
    assert updated_state.program_messages == [{255, "name", obj_id}, {123, "name", obj_id}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["name", "C"])
    assert updated_state.program_messages == [{999, "name", obj_id}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object_id: obj.id}, ["name", "noname"])
    assert updated_state.program_messages == []
  end

  test "SHOOT" do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0},
       %MapTile{character: ".", row: 2, col: 2, z_index: 0},
       %MapTile{character: "#", row: 3, col: 2, z_index: 0, state: "blocking: true"},
       %MapTile{character: "@", row: 2, col: 2, z_index: 1}])

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) -> 
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)

    obj = Instances.get_map_tile(state, %{row: 2, col: 2})

    # shooting into an empty space spawns a bullet heading in that direction
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, ["north"])
    assert bullet = Instances.get_map_tile(updated_state, %{row: 1, col: 2})

    assert bullet.character == "◦"
    assert bullet.parsed_state[:facing] == "north"
    assert updated_state.program_contexts[bullet.id]
    assert updated_state.program_messages == []
    assert updated_state.new_pids == [bullet.id]
    assert updated_state.program_contexts[bullet.id].program.status == :alive

    # shooting into a nil space does nothing (not even throw an exception
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, ["east"])
    refute Instances.get_map_tile(updated_state, %{row: 2, col: 3})

    assert updated_state == state

    # bad direction / idle also does not spawn a bullet or do anything
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, ["gibberish"])
    tile = Instances.get_map_tile(updated_state, %{row: 2, col: 2})

    assert tile.character == "@"
    assert updated_state == state

    # shooting something blocking (or that responds to the SHOT message) sends it that message
    # and does not spawn a bullet
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, ["south"])
    assert wall = Instances.get_map_tile(updated_state, %{row: 3, col: 2})

    assert wall.character == "#"
    assert updated_state.program_contexts == state.program_contexts
    assert updated_state.map_by_ids == state.map_by_ids
    assert updated_state.map_by_coords == state.map_by_coords
    assert updated_state.program_messages == [{wall.id, "shot", %{map_tile_id: obj.id}}]

    # can use the state variable
#    obj = %{obj | parsed_state: %{facing: "north"}}
    {obj, state} = Instances.update_map_tile_state(updated_state, obj, %{facing: "north"})
    %Runner{state: updated_state} = Command.shoot(%Runner{state: state, object_id: obj.id}, [[:state_variable, :facing]])
    assert bullet = Instances.get_map_tile(updated_state, %{row: 1, col: 2})

    assert bullet.character == "◦"
  end

  test "TERMINATE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{program: program, state: state} = Command.terminate(%Runner{program: program, object_id: map_tile.id, state: state})
    updated_map_tile = Instances.get_map_tile_by_id(state, map_tile)
    assert updated_map_tile == Instances.get_map_tile(state, map_tile)
    assert program.status == :dead
    assert program.pc == -1
    assert updated_map_tile.script == ""
  end

  test "text" do
    program = program_fixture()
    stubbed_object = %{id: 1, state: "thing: true"}
    state = %Instances{map_by_ids: %{1 => stubbed_object}}

    %Runner{program: program} = Command.text(%Runner{program: program, object_id: stubbed_object.id, state: state}, ["I am just a simple text."])
    assert program.responses == ["I am just a simple text."]
    assert program.status == :alive
    assert program.pc == 1
  end

  test "TRY" do
    # Basically Move with false
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    assert Command.try(%Runner{object_id: mover.id, state: state}, ["left"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["left", false])

    # Unsuccessful
    assert Command.try(%Runner{object_id: mover.id, state: state}, ["down"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["down", false])
  end

  test "UNLOCK" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{state: state} = Command.unlock(%Runner{program: program, object_id: map_tile.id, state: state}, [])
    map_tile = Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "locked: false"
    assert map_tile.parsed_state == %{locked: false}
  end

  test "WALK" do
    # Basically Move with until it cannot move
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    expected_runner_state = Command.move(%Runner{object_id: mover.id, state: state}, ["left", false])
    expected_runner_state = %Runner{ expected_runner_state | program: %{ expected_runner_state.program | pc: 0 } }

    assert Command.walk(%Runner{state: state, object_id: mover.id}, ["left"]) == expected_runner_state

    # Unsuccessful
    assert Command.walk(%Runner{state: state, object_id: mover.id}, ["down"]) == Command.move(%Runner{object_id: mover.id, state: state}, ["down", false])
  end

  test "WALK with a continue and facing" do
    # Basically Move with until it cannot move
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1, state: "facing: west"})

    expected_runner_state = Command.move(%Runner{object_id: mover.id, state: state}, ["west", false])
    expected_runner_state = %Runner{ expected_runner_state | program: %{ expected_runner_state.program | pc: 0 } }

    assert Command.walk(%Runner{object_id: mover.id, state: state}, ["continue"]) == expected_runner_state
  end

  test "ZAP" do
    program = %Program{ labels: %{"thud" => [[1, true], [5, true]]} }

    runner_state = Command.zap(%Runner{program: program}, ["thud"])
    assert %{"thud" => [[1,false],[5,true]]} == runner_state.program.labels

    runner_state = Command.zap(%{ runner_state | program: runner_state.program}, ["thud"])
    assert %{"thud" => [[1,false],[5,false]]} == runner_state.program.labels

    assert runner_state == Command.zap(runner_state, ["thud"])
    assert runner_state == Command.zap(runner_state, ["derp"])
  end
end

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

    %Runner{object: updated_map_tile, state: state} = Command.become(%Runner{program: program, object: map_tile, state: state}, params)

    assert updated_map_tile == Instances.get_map_tile(state, map_tile)
    assert Map.take(updated_map_tile, [:character, :color]) == %{character: "~", color: "puce"}
  end

  test "BECOME a ttid" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()
    squeaky_door = insert_tile_template(%{script: "#END\n:TOUCH\nSQUEEEEEEEEEK", state: "blocking: true"})
    params = [{:ttid, squeaky_door.id}]

    %Runner{object: updated_map_tile, program: program, state: state} = Command.become(%Runner{program: program, object: map_tile, state: state}, params)
    assert updated_map_tile == Instances.get_map_tile(state, map_tile)

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

    %Runner{object: updated_map_tile, state: state} = Command.change_state(%Runner{program: program, object: map_tile, state: state}, [:add, "+=", 1])
    assert updated_map_tile == Instances.get_map_tile(state, map_tile)
    assert updated_map_tile.state == "add: 9, one: 100"
    %Runner{object: updated_map_tile, state: state} = Command.change_state(%Runner{program: program, object: map_tile, state: state}, [:one, "=", 432])
    assert updated_map_tile.state == "add: 8, one: 432"
    %Runner{object: updated_map_tile, state: _state} = Command.change_state(%Runner{program: program, object: map_tile, state: state}, [:new, "+=", 1])
    assert updated_map_tile.state == "add: 8, new: 1, one: 100"
  end

  test "CYCLE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{object: map_tile, state: state} = Command.cycle(%Runner{program: program, object: map_tile, state: state}, [3])
    assert map_tile == Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "wait_cycles: 3"
    %Runner{object: map_tile, state: state} = Command.cycle(%Runner{program: program, object: map_tile, state: state}, [-2])
    assert map_tile == Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "wait_cycles: 3"
    %Runner{object: map_tile, state: state} = Command.cycle(%Runner{program: program, object: map_tile, state: state}, [1])
    assert map_tile == Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "wait_cycles: 1"
  end

  test "COMPOUND_MOVE" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    # Successful
    %Runner{program: program, object: mover, state: state} = Command.compound_move(%Runner{object: mover, state: state},
                                                                                   [{"west", true}, {"east", true}])
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
    %Runner{program: program, object: mover, state: state} = Command.compound_move(%Runner{object: mover, state: state},
                                                                                   [{"south", false}])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Unsuccessful (but its a retry until successful)
    %Runner{program: program, object: mover, state: state} = Command.compound_move(%Runner{object: mover, state: state},
                                                                                   [{"south", true}, {"east", true}])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0,
             lc: 0
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Last movement already done
    runner_state = %Runner{object: mover, state: state, program: %Program{ status: :alive, lc: 2 }}
    %Runner{program: program, object: _mover, state: _state} = Command.compound_move(runner_state, [{"idle", true}, {"east", true}])
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

    %Runner{program: program} = Command.compound_move(%Runner{program: program, object: mover, state: state}, [{"south", true}])

    assert %{status: :alive,
             wait_cycles: 0,
             broadcasts: [],
             pc: 4,
             lc: 0
           } = program
  end

  test "DIE" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{object: updated_map_tile, program: program, state: state} = Command.die(%Runner{program: program, object: map_tile, state: state})
    assert updated_map_tile == Instances.get_map_tile(state, map_tile)
    assert program.status == :dead
    assert program.pc == -1
    assert updated_map_tile.script == ""
  end

  test "GO" do
    # Basically Move with true
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    assert Command.go(%Runner{object: mover, state: state}, ["left"]) == Command.move(%Runner{object: mover, state: state}, ["left", true])

    # Unsuccessful
    assert Command.go(%Runner{object: mover, state: state}, ["down"]) == Command.move(%Runner{object: mover, state: state}, ["down", true])
  end

  test "HALT/END" do
    program = program_fixture()
    stubbed_object = %{state: ""}

    %Runner{object: _updated_map_tile, program: program, state: _state} = Command.halt(%Runner{program: program, object: stubbed_object})
    assert program.status == :idle
    assert program.pc == -1
  end

  test "FACING" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: ".", state: "facing: up"})
    program = program_fixture()

    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: map_tile, state: state}, ["east"])
    assert updated_map_tile.state == "facing: east"
    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: map_tile, state: state}, ["clockwise"])
    assert updated_map_tile.state == "facing: east"
    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: map_tile, state: state}, ["counterclockwise"])
    assert updated_map_tile.state == "facing: west"
    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: map_tile, state: state}, ["reverse"])
    assert updated_map_tile.state == "facing: south"
    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: map_tile, state: state}, ["player"])
    assert updated_map_tile.state == "facing: idle"

    # Facing to player direction targets that player when it is not targeting a player
    {fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"}, %Location{})
    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: map_tile, state: state}, ["player"])
    assert updated_map_tile.state == "facing: south, target_player_map_tile_id: 43201"

    # Facing to player direction when there is no players sets facing to idle and the target player to nil
    {_fake_player, state} = Instances.delete_map_tile(state, fake_player)
    %Runner{object: updated_map_tile} = Command.facing(%Runner{program: program, object: updated_map_tile, state: state}, ["player"])
    assert updated_map_tile.state == "facing: idle, target_player_map_tile_id: nil"
  end

  test "JUMP_IF when state check is TRUE" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [[:state_variable, :thing], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3

    # with explicit check
    params = [[:state_variable, :thing, "==", true], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 3
  end

  test "JUMP_IF when state check is FALSE" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing], "TOUCH"]

    assert program.status == :alive
    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1

    # with explicit check
    params = [["!", :check_state, :thing, "==", true], "TOUCH"]

    %Runner{program: updated_program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert updated_program.status == :alive
    assert updated_program.pc == 1
  end

  test "JUMP_IF when state check is TRUE but no active label" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing], "TOUCH"]

    program = %{ program | labels: %{"TOUCH" => [[3, false]]} }
    %Runner{program: program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert program.status == :alive
    assert program.pc == 1
  end

  test "LOCK" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{object: map_tile, state: state} = Command.lock(%Runner{program: program, object: map_tile, state: state}, [])
    assert map_tile == Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "locked: true"
    assert map_tile.parsed_state == %{locked: true}
  end

  test "MOVE with one param" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 4, character: "#", row: 0, col: 1, z_index: 0, state: "blocking: true"})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    # Successful
    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["left"])
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
    assert [{1, "touch", nil}] = state.program_messages
    state = %{state | program_messages: []}

    # Unsuccessful (but its a try and move that does not keep trying)
    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["down"])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [] = state.program_messages
    state = %{state | program_messages: []}

    # Unsuccessful - uses the wait cycles from the state
    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["up"])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [{4, "touch", nil}] = state.program_messages
    state = %{state | program_messages: []}

    # Idle
    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["idle"])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover
    assert [] = state.program_messages

    # Moving in player direction targets a player when it is not targeting a player
    {fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43201, row: 2, col: 2, z_index: 0, character: "@"}, %Location{})
    %Runner{object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["player"])
    assert %{row: 1,
             col: 2,
             character: "c",
             state: "facing: east, target_player_map_tile_id: 43201",
             z_index: 1} = mover

    # Moving in player direction keeps after that player
    {another_fake_player, state} = Instances.create_player_map_tile(state, %MapTile{id: 43215, row: 1, col: 5, z_index: 0, character: "@"}, %Location{})
    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["player"])
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: south, target_player_map_tile_id: 43201",
             z_index: 1} = mover

    # When target player leaves dungeon, another target is chosen 
    {_, state} = Instances.delete_map_tile(state, fake_player)
    %Runner{object: mover, state: state} = Command.facing(%Runner{program: program, object: mover, state: state}, ["player"])
    assert %{row: 2,
             col: 2,
             character: "c",
             state: "facing: north, target_player_map_tile_id: 43215",
             z_index: 1} = mover
    {_, state} = Instances.delete_map_tile(state, another_fake_player)

    # Move towards player (will end up being unchanged since no players remaining)
    %Runner{program: program, object: mover} = Command.move(%Runner{object: mover, state: state}, ["player"])
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

    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["left", true])
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
    %Runner{program: program, object: mover, state: _state} = Command.move(%Runner{object: mover, state: state}, ["down", true])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0 # decremented so when runner increments the PC it will still be the current move command
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

    %Runner{program: program} = Command.move(%Runner{program: program, object: mover, state: state}, ["south", true])

    assert %{status: :alive,
             wait_cycles: 0,
             broadcasts: [],
             pc: 4
           } = program
  end

  test "NOOP" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    runner_state = %Runner{object: stubbed_object, program: program}
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
    stubbed_object = %{id: 1337}

    %Runner{state: state} = Command.send_message(%Runner{program: program, object: stubbed_object}, ["touch"])
    assert state.program_messages == [{1337, "touch", nil}]

    # program_messages has more recent messages at the front of the list
    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object: stubbed_object}, ["tap", "self"])
    assert state.program_messages == [{1337, "tap", nil}, {1337, "touch", nil}]
  end

  test "SEND message to others" do
    program = program_fixture()
    stubbed_object = %{id: 1337}
    state = %Instances{program_contexts: %{1337 => %Program{}, 55 => %Program{}, 1 => %Program{}, 9001 => %Program{}}}

    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object: stubbed_object}, ["tap", "others"])
    assert state.program_messages == [{9001, "tap", nil}, {55, "tap", nil}, {1, "tap", nil}]
  end

  test "SEND message to all" do
    program = program_fixture()
    stubbed_object = %{id: 1337}
    state = %Instances{program_contexts: %{1337 => %Program{}, 55 => %Program{}, 1 => %Program{}, 9001 => %Program{}}}

    %Runner{state: state} = Command.send_message(%Runner{state: state, program: program, object: stubbed_object}, ["dance", "all"])
    assert state.program_messages == [{9001, "dance", nil}, {1337, "dance", nil}, {55, "dance", nil}, {1, "dance", nil}]
  end

  test "SEND message to tiles in a direction" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, character: "c", row: 2, col: 2, z_index: 0, state: "facing: north"})

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["touch", "north"])
    assert updated_state.program_messages == [{123, "touch", nil}, {255, "touch", nil}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["touch", "south"])
    assert updated_state.program_messages == [{999, "touch", nil}]

    # Also works if the direction is in a state variable
    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["touch", [:state_variable, :facing]])
    assert updated_state.program_messages == [{123, "touch", nil}, {255, "touch", nil}]

    # Doesnt break if nonexistant state var
    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["touch", [:state_variable, :fake]])
    assert updated_state.program_messages == []
  end

  test "SEND message to tiles by name" do
    state = %Instances{}
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 123,  name: "A", character: ".", row: 1, col: 2, z_index: 0, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 255,  name: "A", character: ".", row: 1, col: 2, z_index: 1, script: "#END"})
    {_, state}   = Instances.create_map_tile(state, %MapTile{id: 999,  name: "C", character: "c", row: 3, col: 2, z_index: 0, script: "#END"})
    {obj, state} = Instances.create_map_tile(state, %MapTile{id: 1337, name: nil, character: "c", row: 2, col: 2, z_index: 0})

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["name", "a"])
    assert updated_state.program_messages == [{255, "name", nil}, {123, "name", nil}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["name", "C"])
    assert updated_state.program_messages == [{999, "name", nil}]

    %Runner{state: updated_state} = Command.send_message(%Runner{state: state, object: obj}, ["name", "noname"])
    assert updated_state.program_messages == []
  end

  test "text" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}

    %Runner{program: program} = Command.text(%Runner{program: program, object: stubbed_object}, ["I am just a simple text."])
    assert program.responses == ["I am just a simple text."]
    assert program.status == :alive
    assert program.pc == 1
  end

  test "TRY" do
    # Basically Move with false
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    assert Command.try(%Runner{object: mover, state: state}, ["left"]) == Command.move(%Runner{object: mover, state: state}, ["left", false])

    # Unsuccessful
    assert Command.try(%Runner{object: mover, state: state}, ["down"]) == Command.move(%Runner{object: mover, state: state}, ["down", false])
  end

  test "UNLOCK" do
    {map_tile, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 123, row: 1, col: 2, z_index: 0, character: "."})
    program = program_fixture()

    %Runner{object: map_tile, state: state} = Command.unlock(%Runner{program: program, object: map_tile, state: state}, [])
    assert map_tile == Instances.get_map_tile(state, map_tile)
    assert map_tile.state == "locked: false"
    assert map_tile.parsed_state == %{locked: false}
  end

  test "WALK" do
    # Basically Move with until it cannot move
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1})

    expected_runner_state = Command.move(%Runner{object: mover, state: state}, ["left", false])
    expected_runner_state = %Runner{ expected_runner_state | program: %{ expected_runner_state.program | pc: 0 } }

    assert Command.walk(%Runner{object: mover, state: state}, ["left"]) == expected_runner_state

    # Unsuccessful
    assert Command.walk(%Runner{object: mover, state: state}, ["down"]) == Command.move(%Runner{object: mover, state: state}, ["down", false])
  end

  test "WALK with a continue and facing" do
    # Basically Move with until it cannot move
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
    {mover, state} = Instances.create_map_tile(state, %MapTile{id: 3, character: "c", row: 1, col: 2, z_index: 1, state: "facing: west"})

    expected_runner_state = Command.move(%Runner{object: mover, state: state}, ["west", false])
    expected_runner_state = %Runner{ expected_runner_state | program: %{ expected_runner_state.program | pc: 0 } }

    assert Command.walk(%Runner{object: mover, state: state}, ["continue"]) == expected_runner_state
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

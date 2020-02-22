defmodule DungeonCrawl.Scripting.CommandTest do
  use DungeonCrawl.DataCase

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
    assert Command.get_command(:die) == :die
    assert Command.get_command(:end) == :halt    # exception to the naming convention, cant "def end do"
    assert Command.get_command(:if) == :jump_if
    assert Command.get_command(:noop) == :noop
    assert Command.get_command(:text) == :text

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
    squeaky_door = insert_tile_template(%{script: "#END\n:TOUCH\nSQUEEEEEEEEEK"})
    params = [{:ttid, squeaky_door.id}]

    %Runner{object: updated_map_tile, program: program, state: state} = Command.become(%Runner{program: program, object: map_tile, state: state}, params)
    assert updated_map_tile == Instances.get_map_tile(state, map_tile)

    refute Map.take(updated_map_tile, [:script]) == %{script: map_tile.script}
    assert Map.take(updated_map_tile, [:character, :color, :script]) == Map.take(squeaky_door, [:character, :color, :script])
    assert program.status == :idle
    assert %{1 => [:halt, [""]],
             2 => [:noop, "TOUCH"],
             3 => [:text, ["SQUEEEEEEEEEK"]]} = program.instructions
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
    %Runner{program: program, object: mover, state: _state} = Command.compound_move(runner_state, [{"idle", true}, {"east", true}])
    assert %{status: :alive,
             wait_cycles: 0,
             broadcasts: [],
             pc: 1,
             lc: 0
           } = program
    assert updated_object2 = mover
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

  test "HALT/END" do
    program = program_fixture()
    stubbed_object = %{state: ""}

    %Runner{object: _updated_map_tile, program: program, state: _state} = Command.halt(%Runner{program: program, object: stubbed_object})
    assert program.status == :idle
    assert program.pc == -1
  end

  test "JUMP_IF when state check is TRUE" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["", :check_state, :thing, "", ""], "TOUCH"]

    %Runner{program: program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert program.status == :alive
    assert program.pc == 3
  end

  test "JUMP_IF when state check is FALSE" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing, "", ""], "TOUCH"]

    assert program.status == :alive
    %Runner{program: program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert program.status == :alive
    assert program.pc == 1
  end

  test "JUMP_IF when state check is TRUE but no active label" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing, "", ""], "TOUCH"]

    program = %{ program | labels: %{"TOUCH" => [[3, false]]} }
    %Runner{program: program} = Command.jump_if(%Runner{program: program, object: stubbed_object}, params)
    assert program.status == :alive
    assert program.pc == 1
  end

  test "MOVE with one param" do
    {_, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, character: ".", row: 1, col: 1, z_index: 0})
    {_, state} = Instances.create_map_tile(state, %MapTile{id: 2, character: ".", row: 1, col: 2, z_index: 0})
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

    # Unsuccessful (but its a try and move that does not keep trying)
    %Runner{program: program, object: mover, state: state} = Command.move(%Runner{object: mover, state: state}, ["down"])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = mover

    # Idle
    %Runner{program: program, object: mover, state: _state} = Command.move(%Runner{object: mover, state: state}, ["idle"])
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = program
    assert updated_object2 = mover
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

  test "text" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}

    %Runner{program: program} = Command.text(%Runner{program: program, object: stubbed_object}, ["I am just a simple text."])
    assert program.responses == ["I am just a simple text."]
    assert program.status == :alive
    assert program.pc == 1
  end
end

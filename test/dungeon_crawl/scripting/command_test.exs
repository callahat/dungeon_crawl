defmodule DungeonCrawl.Scripting.CommandTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program

  def map_tile_fixture(attrs \\ %{}) do
    impassable_floor = insert_tile_template(attrs)
    
    dungeon = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 1, col: 2, tile_template_id: impassable_floor.id, z_index: 0},
                 Map.take(impassable_floor, [:character,:color,:background_color,:state,:script]))])
    DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2
  end

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
    assert Command.get_command(:if) == :if
    assert Command.get_command(:noop) == :noop
    assert Command.get_command(:text) == :text

    refute Command.get_command(:fake_not_real)
  end

  test "BECOME" do
    program = program_fixture()
    map_tile = map_tile_fixture()
    params = [%{character: "~", color: "puce"}]

    %{object: updated_map_tile, program: _program} = Command.become(%{program: program, object: map_tile, params: params})

    refute Map.take(map_tile, [:character, :color]) == %{character: "~", color: "puce"}
    assert Map.take(updated_map_tile, [:character, :color]) == %{character: "~", color: "puce"}
  end

  test "BECOME a ttid" do
    program = program_fixture()
    map_tile = map_tile_fixture()
    squeaky_door = insert_tile_template(%{script: "#END\n:TOUCH\nSQUEEEEEEEEEK"})
    params = [{:ttid, squeaky_door.id}]

    %{object: updated_map_tile, program: program} = Command.become(%{program: program, object: map_tile, params: params})

    refute Map.take(updated_map_tile, [:script]) == %{script: map_tile.script}
    assert Map.take(updated_map_tile, [:character, :color, :script]) == Map.take(squeaky_door, [:character, :color, :script])
    assert program.status == :idle
    assert %{1 => [:halt, [""]],
             2 => [:noop, "TOUCH"],
             3 => [:text, ["SQUEEEEEEEEEK"]]} = program.instructions
  end

  test "CHANGE_STATE" do
    program = program_fixture()
    map_tile = map_tile_fixture(%{state: "one: 100, add: 8"})

    %{object: updated_map_tile, program: _program} = Command.change_state(%{program: program, object: map_tile, params: [:add, "+=", 1]})
    assert updated_map_tile.state == "add: 9, one: 100"
    %{object: updated_map_tile, program: _program} = Command.change_state(%{program: program, object: map_tile, params: [:one, "=", 432]})
    assert updated_map_tile.state == "add: 8, one: 432"
    %{object: updated_map_tile, program: _program} = Command.change_state(%{program: program, object: map_tile, params: [:new, "+=", 1]})
    assert updated_map_tile.state == "add: 8, new: 1, one: 100"
  end

  test "DIE" do
    program = program_fixture()
    map_tile = map_tile_fixture(%{script: "it does soemthing and this is a fake script"})

    %{object: updated_map_tile, program: program} = Command.die(%{program: program, object: map_tile})

    assert program.status == :dead
    assert program.pc == -1
    assert updated_map_tile.script == ""
  end

  test "HALT/END" do
    program = program_fixture()
    stubbed_object = %{state: ""}

    %{object: _, program: program} = Command.halt(%{program: program, object: stubbed_object})
    assert program.status == :idle
    assert program.pc == -1
  end

  test "IF when state check is TRUE" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["", :check_state, :thing, "", ""], "TOUCH"]

    %{object: _, program: program} = Command.if(%{program: program, object: stubbed_object, params: params})
    assert program.status == :alive
    assert program.pc == 3
  end

  test "IF when state check is FALSE" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing, "", ""], "TOUCH"]

    assert program.status == :alive
    %{object: _, program: program} = Command.if(%{program: program, object: stubbed_object, params: params})
    assert program.status == :alive
    assert program.pc == 1
  end

  test "IF when state check is TRUE but no active label" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    params = [["!", :check_state, :thing, "", ""], "TOUCH"]

    program = %{ program | labels: %{"TOUCH" => [[3, false]]} }
    %{object: _, program: program} = Command.if(%{program: program, object: stubbed_object, params: params})
    assert program.status == :alive
    assert program.pc == 1
  end

  defp _setup_move_test do
    tt = insert_tile_template(%{state: "blocking: false"})

    insert_stubbed_dungeon_instance(
      %{},
      [%MapTile{character: ".", row: 1, col: 1, z_index: 0, tile_template_id: tt.id},
       %MapTile{character: ".", row: 1, col: 2, z_index: 0, tile_template_id: tt.id},
       %MapTile{character: "c", row: 1, col: 2, z_index: 1, tile_template_id: tt.id}])
  end

  test "MOVE with one param" do
    _setup_move_test()

    mover = DungeonCrawl.Repo.get_by(MapTile, %{row: 1, col: 2, z_index: 1})

    # Successful
    assert %{program: updated_program, object: updated_object} = Command.move(%{program: %Program{}, object: mover, params: ["left"]})
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
           } = updated_program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = updated_object

    # Unsuccessful (but its a try and move that does not keep trying)
    assert %{program: updated_program, object: updated_object2} = Command.move(%{program: %Program{}, object: updated_object, params: ["down"]})
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 1
           } = updated_program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = updated_object2
  end

  test "MOVE with two params" do
    _setup_move_test()

    mover = DungeonCrawl.Repo.get_by(MapTile, %{row: 1, col: 2, z_index: 1})

    assert %{program: updated_program, object: updated_object} = Command.move(%{program: %Program{}, object: mover, params: ["left", true]})
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
           } = updated_program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = updated_object

    # Unsuccessful
    assert %{program: updated_program, object: updated_object2} = Command.move(%{program: %Program{}, object: updated_object, params: ["down", true]})
    assert %{status: :wait,
             wait_cycles: 5,
             broadcasts: [],
             pc: 0 # decremented so when runner increments the PC it will still be the current move command
           } = updated_program
    assert %{row: 1, col: 1, character: "c", z_index: 1} = updated_object2
  end

  test "NOOP" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}
    assert %{object: stubbed_object, program: program} == Command.noop(%{program: program, object: stubbed_object})
  end

  test "text" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}

    %{object: _, program: program} = Command.text(%{program: program, object: stubbed_object, params: ["I am just a simple text."]})
    assert program.responses == ["I am just a simple text."]
    assert program.status == :alive
    assert program.pc == 1
  end
end

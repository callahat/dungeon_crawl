defmodule DungeonCrawl.Scripting.CommandTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Parser

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

  test "text" do
    program = program_fixture()
    stubbed_object = %{state: "thing: true"}

    %{object: _, program: program} = Command.text(%{program: program, object: stubbed_object, params: ["I am just a simple text."]})
    assert program.responses == ["I am just a simple text."]
    assert program.status == :alive
    assert program.pc == 1
  end
end

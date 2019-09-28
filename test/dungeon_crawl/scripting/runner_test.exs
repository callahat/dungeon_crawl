defmodule DungeonCrawl.Scripting.RunnerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Runner

  describe "run" do
    test "END command" do
      script = """
               #END
               does not run this
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: ""}

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: stubbed_object})
      assert program.status == :idle
      assert program.pc == 0
    end

    test "IF command when state check is TRUE" do
      script = """
               #IF @thing, OK
               Dont hit this
               #END
               :OK
               Does run this
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: "thing: true"}

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: stubbed_object})
      assert program.responses == ["Does run this"]
      assert program.status == :idle
      assert program.pc == 0
    end

    test "IF command when state check is FALSE" do
      script = """
               #IF not @thing, OK
               First text
               #END
               :OK
               Second text
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: "thing: true"}

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: stubbed_object})
      assert program.responses == ["First text"]
      assert program.status == :idle
      assert program.pc == 0
    end

    test "BECOME command" do
      script = """
               #BECOME character: ', color: red, background_color: white
               """
      {:ok, program} = Parser.parse(script)
      impassable_floor = insert_tile_template()

      dungeon = insert_stubbed_dungeon_instance(%{},
        [Map.merge(%{row: 1, col: 2, tile_template_id: impassable_floor.id, z_index: 0},
                   Map.take(impassable_floor, [:character,:color,:background_color,:state,:script]))])
      map_tile = DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: map_tile})
      update_map_tile = DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2
      assert program.status == :idle
      assert program.pc == 0
      refute Map.take(map_tile, [:character, :color, :background_color]) == %{character: "'", color: "red", background_color: "white"}
      assert Map.take(update_map_tile, [:character, :color, :background_color]) == %{character: "'", color: "red", background_color: "white"}
    end

    test "setting a state value" do
      script = """
               @one = 1
               @add += 12
               """
      {:ok, program} = Parser.parse(script)
      impassable_floor = insert_tile_template(%{state: "one: 100, add: 8", script: script})

      dungeon = insert_stubbed_dungeon_instance(%{},
        [Map.merge(%{row: 1, col: 2, tile_template_id: impassable_floor.id, z_index: 0},
                   Map.take(impassable_floor, [:character,:color,:background_color, :state, :script]))])
      map_tile = DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: map_tile})
      update_map_tile = DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2
      assert program.status == :idle
      assert program.pc == 0
      assert update_map_tile.state == "add: 20, one: 1"
    end

    test "DIE command" do
      script = """
               #DIE
               does not run this
               """
      {:ok, program} = Parser.parse(script)
      impassable_floor = insert_tile_template(%{script: script})

      dungeon = insert_stubbed_dungeon_instance(%{},
        [Map.merge(%{row: 1, col: 2, tile_template_id: impassable_floor.id, z_index: 0},
                   Map.take(impassable_floor, [:character,:color,:background_color, :state, :script]))])
      map_tile = DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: map_tile})
      update_map_tile = DungeonCrawl.DungeonInstances.get_map_tile! dungeon.id, 1, 2
      assert program.status == :dead
      assert program.pc == 0
      assert update_map_tile.script == ""
    end

    test "text" do
      script = """
               I am just a simple text.
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: ""}

      assert program.status == :alive
      %{object: _, program: program} = Runner.run(%{program: program, object: stubbed_object})
      assert program.responses == ["I am just a simple text."]
      assert program.status == :idle
      assert program.pc == 0
    end

    test "executes from current pc" do
      script = """
               Line One
               Line Two
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: ""}

      %{object: _, program: run_program} = Runner.run(%{program: program, object: stubbed_object})
      assert run_program.responses == ["Line Two", "Line One"]

      %{object: _, program: run_program} = Runner.run(%{program: %{program | pc: 2}, object: stubbed_object})
      assert run_program.responses == ["Line Two"]
    end

    test "when given a label executes from that" do
      script = """
               B4 label
               :HERE
               After label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: ""}

      %{object: _, program: run_program} = Runner.run(%{program: program, object: stubbed_object, label: "HERE"})
      assert run_program.responses == ["After label"]
    end

    test "when given a nonexistent label returns the program with a helpful message in the responses" do
      script = """
               B4 label
               :HERE
               After label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: ""}

      %{object: _, program: run_program} = Runner.run(%{program: program, object: stubbed_object, label: "NOT_A_REAL_LABEL"})
      assert run_program.responses == ["Label not in script: NOT_A_REAL_LABEL"]
    end
  end
end

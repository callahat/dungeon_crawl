defmodule DungeonCrawl.Scripting.RunnerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.DungeonProcesses.Instances

  describe "run" do
    test "executes from current pc" do
      script = """
               #end
               Line One
               Line Two
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      state = %Instances{map_by_ids: %{1 => stubbed_object}}

      %Runner{program: run_program} = Runner.run(%Runner{state: state, program: program, object_id: stubbed_object.id})
      assert run_program.responses == []
      assert run_program.status == :idle

      %Runner{program: run_program} = Runner.run(%Runner{state: state, program: %{program | pc: 2}, object_id: stubbed_object.id})
      assert run_program.responses == [{"message", %{message: ["Line One", "Line Two"], modal: true}}]

      %Runner{program: run_program} = Runner.run(%Runner{state: state, program: %{program | pc: 3}, object_id: stubbed_object.id})
      assert run_program.responses == [{"message", %{message: "Line Two"}}]
    end

    test "when program is idle it runs nothing and just returns the program and object" do
      program = %Program{status: :idle, pc: 2}
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }
      %Runner{state: state, program: run_program} = Runner.run(%Runner{program: program, object_id: 1, state: stubbed_state})
      assert program == run_program
      assert state  == stubbed_state
    end

    test "when program is dead runs nothing and just returns the program and object" do
      program = %Program{status: :dead, pc: 2}
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }
      %Runner{state: state, program: run_program} = Runner.run(%Runner{program: program, object_id: 1, state: stubbed_state})
      assert program == run_program
      assert state  == stubbed_state
    end

    test "when program is wait, program becomes alive" do
      program = %Program{status: :wait, pc: 2}
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }
      %Runner{state: state, program: run_program} = Runner.run(%Runner{program: program, object_id: 1, state: stubbed_state})
      assert run_program.status == :alive
      assert state == stubbed_state
    end

    test "when the programs map tile is gone the program dies" do
      program = %Program{status: :wait, pc: 2}
      stubbed_state = %Instances{map_by_ids: %{} }
      %Runner{state: state, program: run_program} = Runner.run(%Runner{program: program, object_id: 1, state: stubbed_state})
      assert run_program.status == :dead
      assert state == stubbed_state
    end
  end
end

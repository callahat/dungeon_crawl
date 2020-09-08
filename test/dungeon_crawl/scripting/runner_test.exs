defmodule DungeonCrawl.Scripting.RunnerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.DungeonProcesses.Instances

  describe "run" do
    test "executes from current pc" do
      script = """
               Line One
               Line Two
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      state = %Instances{map_by_ids: %{1 => stubbed_object}}

      %Runner{program: run_program} = Runner.run(%Runner{state: state, program: program, object_id: stubbed_object.id})
      assert run_program.responses == [{"message", %{message: "Line Two"}}, {"message", %{message: "Line One"}}]

      %Runner{program: run_program} = Runner.run(%Runner{state: state, program: %{program | pc: 2}, object_id: stubbed_object.id})
      assert run_program.responses == [{"message", %{message: "Line Two"}}]
    end

    test "when given a label executes from that" do
      script = """
               B4 label
               :HERE
               After label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      state = %Instances{map_by_ids: %{1 => stubbed_object}}

      %Runner{program: run_program} = Runner.run(%Runner{state: state, program: %{program | status: :idle}, object_id: stubbed_object.id}, "Here")
      assert run_program.responses == [{"message", %{message: "After label"}}]
    end

    test "when there are messages in the queue" do
      script = """
               B4 label
               :HERE
               After label
               #END
               :THERE
               Last text
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | messages: [{"there", nil}], status: :idle}, object_id: 1, state: stubbed_state})
      assert run_program.responses == [{"message", %{message: "Last text"}}]
      assert run_program.messages == []

      # A label passed in runs from there if possible, then runs queued messages when idle/waiting
      # And runs messages in order sent (oldest first)
      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | messages: [{"there", nil}, {"there", nil}]}, object_id: 1, state: stubbed_state}, "here")
      assert run_program.messages == []
      assert run_program.responses == [{"message", %{message: "Last text"}}, {"message", %{message: "Last text"}}, {"message", %{message: "After label"}}]
    end

    test "when given a label but the label is inactive it does not executes from that" do
      script = """
               B4 label
               :HERE
               After label
               :HERE
               After Active label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | labels: %{"here" => [[2,false], [4,true]]}, status: :idle},
                                                         object_id: stubbed_object.id,
                                                         state: stubbed_state },
                                                 "Here")
      assert run_program.responses == [{"message", %{message: "After Active label"}}]
    end

    test "when given a label but the program is locked it does not change the pc to the label" do
      script = """
               B4 label
               #END
               :HERE
               After label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "locked: true", parsed_state: %{locked: true}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | status: :idle}, object_id: 1, state: stubbed_state}, "Here")
      assert run_program.pc == 1
      assert run_program.responses == []
    end

    test "when given a label but no label matches" do
      script = "No label"
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }

      assert %Runner{state: stubbed_state, program: %{program | status: :idle}, object_id: 1} == 
             Runner.run(%Runner{program: %{program | status: :idle}, object_id: 1, state: stubbed_state}, "TOUCH")
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

    test "when program is wait the wait_cycles are decremented" do
      program = %Program{status: :wait, pc: 2, wait_cycles: 3}
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }
      %Runner{state: state, program: run_program} = Runner.run(%Runner{program: program, object_id: 1, state: stubbed_state})
      assert run_program.wait_cycles == 2
      assert run_program.status == :wait
      assert state == stubbed_state
    end

    test "when program is wait and wait_cycles become zero, program becomes alive" do
      program = %Program{status: :wait, pc: 2, wait_cycles: 1}
      stubbed_object = %{id: 1, state: "", parsed_state: %{}}
      stubbed_state = %Instances{map_by_ids: %{ 1 => stubbed_object} }
      %Runner{state: state, program: run_program} = Runner.run(%Runner{program: program, object_id: 1, state: stubbed_state})
      assert run_program.wait_cycles == 0
      assert run_program.status == :alive
      assert state == stubbed_state
    end
  end
end

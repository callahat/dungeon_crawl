defmodule DungeonCrawl.Scripting.RunnerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Scripting.Runner

  describe "run" do
    test "executes from current pc" do
      script = """
               Line One
               Line Two
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: "", parsed_state: %{}}

      %Runner{program: run_program} = Runner.run(%Runner{program: program, object: stubbed_object})
      assert run_program.responses == ["Line Two", "Line One"]

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | pc: 2}, object: stubbed_object})
      assert run_program.responses == ["Line Two"]
    end

    test "when given a label executes from that" do
      script = """
               B4 label
               :HERE
               After label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: "", parsed_state: %{}}

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | status: :idle}, object: stubbed_object}, "Here")
      assert run_program.responses == ["After label"]
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
      stubbed_object = %{state: "", parsed_state: %{}}

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | message: {"there", nil}}, object: stubbed_object})
      assert run_program.responses == ["Last text"]
      assert run_program.message == {}

      # A label passed in overrides the existing message
      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | message: {"there", nil}}, object: stubbed_object}, "here")
      assert run_program.responses == ["After label"]
      assert run_program.message == {}
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
      stubbed_object = %{state: "", parsed_state: %{}}

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | labels: %{"here" => [[2,false], [4,true]]}, status: :idle},
                                                                              object: stubbed_object},
                                                 "Here")
      assert run_program.responses == ["After Active label"]
    end

    test "when given a label but the program is locked it does not change the pc to the label" do
      script = """
               B4 label
               #END
               :HERE
               After label
               """
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: "locked: true", parsed_state: %{locked: true}}

      %Runner{program: run_program} = Runner.run(%Runner{program: %{program | status: :idle}, object: stubbed_object}, "Here")
      assert run_program.pc == 1
      assert run_program.responses == []
    end

    test "when given a label but no label matches" do
      script = "No label"
      {:ok, program} = Parser.parse(script)
      stubbed_object = %{state: "", parsed_state: %{}}

      assert %Runner{object: stubbed_object, program: %{program | status: :idle}} == 
             Runner.run(%Runner{program: %{program | status: :idle}, object: stubbed_object}, "TOUCH")
    end

    test "when program is idle it runs nothing and just returns the program and object" do
      program = %Program{status: :idle, pc: 2}
      stubbed_object = %{state: "", parsed_state: %{}}
      %Runner{object: object, program: run_program} = Runner.run(%Runner{program: program, object: stubbed_object})
      assert program == run_program
      assert object  == stubbed_object
    end

    test "when program is dead runs nothing and just returns the program and object" do
      program = %Program{status: :dead, pc: 2}
      stubbed_object = %{state: "", parsed_state: %{}}
      %Runner{object: object, program: run_program} = Runner.run(%Runner{program: program, object: stubbed_object})
      assert program == run_program
      assert object  == stubbed_object
    end

    test "when program is wait the wait_cycles are decremented" do
      program = %Program{status: :wait, pc: 2, wait_cycles: 3}
      stubbed_object = %{state: "", parsed_state: %{}}
      %Runner{object: _object, program: run_program} = Runner.run(%Runner{program: program, object: stubbed_object})
      assert run_program.wait_cycles == 2
      assert run_program.status == :wait
    end

    test "when program is wait and wait_cycles become zero, program becomes alive" do
      program = %Program{status: :wait, pc: 2, wait_cycles: 1}
      stubbed_object = %{state: "", parsed_state: %{}}
      %Runner{object: _object, program: run_program} = Runner.run(%Runner{program: program, object: stubbed_object})
      assert run_program.wait_cycles == 0
      assert run_program.status == :alive
    end
  end
end

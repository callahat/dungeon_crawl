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

      %{object: _, program: run_program} = Runner.run(%{program: %{program | status: :idle}, object: stubbed_object, label: "HERE"})
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

    test "when program is idle it runs nothing and just returns the program and object" do
      program = %Program{status: :idle, pc: 2}
      stubbed_object = %{state: ""}
      %{object: object, program: run_program} = Runner.run(%{program: program, object: stubbed_object})
      assert program == run_program
      assert object  == stubbed_object
    end

    test "when program is dead runs nothing and just returns the program and object" do
      program = %Program{status: :dead, pc: 2}
      stubbed_object = %{state: ""}
      %{object: object, program: run_program} = Runner.run(%{program: program, object: stubbed_object})
      assert program == run_program
      assert object  == stubbed_object
    end
  end
end

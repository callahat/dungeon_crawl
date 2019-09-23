defmodule DungeonCrawl.Scripting.ParserTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program

  doctest Parser

  describe "parse" do
    test "no script" do
      assert {:ok, %Program{}} == Parser.parse(nil)
      assert {:ok, %Program{}} == Parser.parse("")
    end

    test "simple script" do
      assert {:ok, program = %Program{}} = Parser.parse("#BECOME character: '")
      assert program == %Program{instructions: %{1 => [:become, [%{character: "'"}]]},
                                 status: :alive,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "script with labels" do
      script = """
               #END
               :TOUCH
               #IF @open, ALREADY_OPEN
               #BECOME character: ', color: white
               #END
               :ALREADY_OPEN
               Door is already open. Can't open it anymore.
               """
      assert {:ok, program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{1 => [:end_script, [""]],
                                                 2 => [:noop, "TOUCH"],
                                                 3 => [:jump_if, [["", :check_state, :open, "==", true], "ALREADY_OPEN"]],
                                                 4 => [:become, [%{character: "'", color: "white"}]],
                                                 5 => [:end_script, [""]],
                                                 6 => [:noop, "ALREADY_OPEN"],
                                                 7 => [:text, ["Door is already open. Can't open it anymore."]]
                                                 },
                                 status: :alive,
                                 pc: 1,
                                 labels: %{"ALREADY_OPEN" => [[6, true]], "TOUCH" => [[2, true]]},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end
  end
end

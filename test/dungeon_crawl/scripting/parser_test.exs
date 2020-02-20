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

    test "script with everything" do
      tile_template = insert_tile_template()
      script = """
               #END
               :TOUCH
               #IF @open, ALREADY_OPEN
               #BECOME character: ', color: white
               The door creaks open
               #END
               :ALREADY_OPEN
               Door is already open.
               Can't open it anymore.
               @counter += 1
               #BECOME TTID:#{tile_template.id}
               #MOVE south, true
               #MOVE east
               \\n\\n?n
               """
      assert {:ok, program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{1 => [:halt, [""]],
                                                 2 => [:noop, "TOUCH"],
                                                 3 => [:jump_if, [["", :check_state, :open, "==", true], "ALREADY_OPEN"]],
                                                 4 => [:become, [%{character: "'", color: "white"}]],
                                                 5 => [:text, ["The door creaks open"]],
                                                 6 => [:halt, [""]],
                                                 7 => [:noop, "ALREADY_OPEN"],
                                                 8 => [:text, ["Door is already open."]],
                                                 9 => [:text, ["Can't open it anymore."]],
                                                 10 => [:change_state, [:counter, "+=", 1]],
                                                 11 => [:become, [{:ttid, tile_template.id}]],
                                                 12 => [:move, ["south", true]],
                                                 13 => [:move, ["east"]],
                                                 14 => [:compound_move, [["north", true], ["north", true], ["north", false]]]
                                                 },
                                 status: :alive,
                                 pc: 1,
                                 labels: %{"ALREADY_OPEN" => [[7, true]], "TOUCH" => [[2, true]]},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "a bad command" do
      script = """
               :MAIN
               #
               Doesnt parse to here
               """
      assert {:error, "Invalid command: ``", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{1 => [:noop, "MAIN"]},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{"MAIN" => [[1, true]] },
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "a nonexistant command" do
      script = """
               #FAKE_COMMAND
               Doesnt parse to here
               """
      assert {:error, "Unknown command: `FAKE_COMMAND`", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "a bad label" do
      script = """
               #END
               :$blabel 
               """
      assert {:error, "Invalid label: `$blabel`", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{1 => [:halt, [""]]},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}

    end

    test "a bad state setting" do
      script = """
               @$blabel = 9
               """
      assert {:error, "Invalid state setting: `$blabel = 9`", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "a bad state assignment" do
      script = """
               @thing + 2049
               """
      assert {:error, "Invalid state assignment: ` + 2049`", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "varous KWARGS for the BECOME command" do
      # Character as whitespace
      valid_kwargs "#BECOME character:  ", %{character: " "}
      valid_kwargs "#BECOME character:  , color: red", %{character: " ", color: "red"}
      valid_kwargs "#BECOME character:  , color: red, background_color: blue", %{character: " ", color: "red", background_color: "blue"}

      # Character as a comma
      valid_kwargs "#BECOME character: ,", %{character: ","}
      valid_kwargs "#BECOME character: ,, color: red ", %{character: ",", color: "red"}
      valid_kwargs "#BECOME character: ,, color: red, background_color: blue", %{character: ",", color: "red", background_color: "blue"}

      # Bad inputs
      invalid_kwargs "#BECOME character: "
      invalid_kwargs "#BECOME character: x,color: red"
      invalid_kwargs "#BECOME character:,"
      invalid_kwargs "#BECOME character: ,,"
      invalid_kwargs "#BECOME character: ,, color: red,"
    end

    defp valid_kwargs script, expected_map do
      assert {:ok, %Program{instructions: %{1 => [:become, params]}}} = Parser.parse(script)
      assert params == [expected_map]
    end

    defp invalid_kwargs script do
      assert {:ok, %Program{instructions: %{1 => [:become, params]}}} = Parser.parse(script)
      assert is_list(params)
    end
  end
end

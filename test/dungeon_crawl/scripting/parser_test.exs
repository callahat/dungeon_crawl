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
               /n/n?n
               #GO west
               #TRY south
               #WALK north
               #FACING clockwise
               #CYCLE 2
               #ZAP touch
               #RESTORE touch
               :TOUCH
               #SEND do_something, others
               #SEND already_open
               #SEND touch, @facing
               #IF ! @open, ALREADY_OPEN
               #IF @open == false, ALREADY_OPEN
               #IF not @open == false, ALREADY_OPEN
               #SHOOT north
               #SHOOT @facing
               #TERMINATE
               """
      assert {:ok, program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{1 => [:halt, [""]],
                                                 2 => [:noop, "TOUCH"],
                                                 3 => [:jump_if, [[:state_variable, :open], "ALREADY_OPEN"]],
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
                                                 14 => [:compound_move, [{"north", true}, {"north", true}, {"north", false}]],
                                                 15 => [:go, ["west"]],
                                                 16 => [:try, ["south"]],
                                                 17 => [:walk, ["north"]],
                                                 18 => [:facing, ["clockwise"]],
                                                 19 => [:cycle, [2]],
                                                 20 => [:zap, ["touch"]],
                                                 21 => [:restore, ["touch"]],
                                                 22 => [:noop, "TOUCH"],
                                                 23 => [:send_message, ["do_something", "others"]],
                                                 24 => [:send_message, ["already_open"]],
                                                 25 => [:send_message, ["touch", [:state_variable, :facing]]],
                                                 26 => [:jump_if, [["!", :state_variable, :open], "ALREADY_OPEN"]],
                                                 27 => [:jump_if, [[:state_variable, :open, "==", false], "ALREADY_OPEN"]],
                                                 28 => [:jump_if, [["!", :state_variable, :open, "==", false], "ALREADY_OPEN"]],
                                                 29 => [:shoot, ["north"]],
                                                 30 => [:shoot, [[:state_variable, :facing]]],
                                                 31 => [:terminate, [""]],
                                                 },
                                 status: :alive,
                                 pc: 1,
                                 labels: %{"already_open" => [[7, true]], "touch" => [[2, true],[22,true]]},
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
                                 labels: %{"main" => [[1, true]] },
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

    test "bad shorthand movements" do
      script = """
               ?n/u?L
               Doesnt parse to here
               """
      assert {:error, "Invalid shorthand movement: /u", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
      assert {:error, "Invalid shorthand movement: @i", program = %Program{}} = Parser.parse("/w@i")
    end
  end
end

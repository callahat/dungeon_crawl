defmodule DungeonCrawl.Scripting.ParserTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scripting.Parser
  alias DungeonCrawl.Scripting.Program

  # To verify the parsed stuff feeds into the commands, might move this elsewhere
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Runner

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
               #SEND touch, ?sender
               #GIVE ammo, @rounds, ?sender
               #GIVE health, 10, ?sender
               #GIVE gems, 1, north
               #TAKE gems, 1, north
               #TAKE cash, 10, ?sender, toopoor
               #IF ?@open, TOUCH
               #IF ?sender@blocking, TOUCH
               #IF ! ?north@blocking, TOUCH
               #IF @@flag, TOUCH
               @@red_flag = true
               #GIVE @color+_key, 1, ?sender, 1
               #GIVE @color+_key, 1, ?sender, 1, alreadyhave
               :ALREADYHAVE
               #BECOME color: ?north@color
               #BECOME character: @char
               #REPLACE target_color: red, color: blue
               #PUT slug: expanding_foam, direction: south, color: @color
               #PUSH north, 1
               #PUSH @facing
               #SHIFT clockwise
               #IF ?{@facing}@blocking, TOUCH
               #IF ?random@10 < 7, TOUCH
               #MOVE @facing
               #GO @facing
               #TRY @facing
               ?{?sender}@health = 1
               ?north@blocking = true
               ?12345@pullable = false
               ?{@facing}@health -= 10
               #PASSAGE @background_color
               #TRANSPORT ?sender, up
               #TRANSPORT @target_player, 2, red
               !buy;buy some more
               #RANDOM dir, NORTH, SOUTH, PLAYER
               #SEQUENCE c, <, ^, >, v
               #IF @ok, 3
               #IF @notok
               #TARGET_PLAYER nearest
               """
      assert {:ok, program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{1 => [:halt, [""]],
                                                 2 => [:noop, "TOUCH"],
                                                 3 => [:jump_if, [{:state_variable, :open}, "ALREADY_OPEN"]],
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
                                                 25 => [:send_message, ["touch", {:state_variable, :facing}]],
                                                 26 => [:jump_if, [["!", {:state_variable, :open}], "ALREADY_OPEN"]],
                                                 27 => [:jump_if, [[{:state_variable, :open}, "==", false], "ALREADY_OPEN"]],
                                                 28 => [:jump_if, [["!", {:state_variable, :open}, "==", false], "ALREADY_OPEN"]],
                                                 29 => [:shoot, ["north"]],
                                                 30 => [:shoot, [{:state_variable, :facing}]],
                                                 31 => [:terminate, [""]],
                                                 32 => [:send_message, ["touch", [:event_sender]]],
                                                 33 => [:give, ["ammo", {:state_variable, :rounds}, [:event_sender]]],
                                                 34 => [:give, ["health", 10, [:event_sender]]],
                                                 35 => [:give, ["gems", 1, "north"]],
                                                 36 => [:take, ["gems", 1, "north"]],
                                                 37 => [:take, ["cash", 10, [:event_sender], "toopoor"]],
                                                 38 => [:jump_if, [{:event_sender_variable, :open}, "TOUCH"]],
                                                 39 => [:jump_if, [{:event_sender_variable, :blocking}, "TOUCH"]],
                                                 40 => [:jump_if, [["!", {{:direction, "north"}, :blocking}], "TOUCH"]],
                                                 41 => [:jump_if, [{:instance_state_variable, :flag}, "TOUCH"]],
                                                 42 => [:change_instance_state, [:red_flag, "=", true]],
                                                 43 => [:give, [{:state_variable, :color, "_key"}, 1, [:event_sender], 1]],
                                                 44 => [:give, [{:state_variable, :color, "_key"}, 1, [:event_sender], 1, "alreadyhave"]],
                                                 45 => [:noop, "ALREADYHAVE"],
                                                 46 => [:become, [%{color: {{:direction, "north"}, :color}}]],
                                                 47 => [:become, [%{character: {:state_variable, :char}}]],
                                                 48 => [:replace, [%{target_color: "red", color: "blue"}]],
                                                 49 => [:put, [%{slug: "expanding_foam", direction: "south", color: {:state_variable, :color}}]],
                                                 50 => [:push, ["north", 1]],
                                                 51 => [:push, [{:state_variable, :facing}]],
                                                 52 => [:shift, ["clockwise"]],
                                                 53 => [:jump_if, [{{:state_variable, :facing}, :blocking}, "TOUCH"]],
                                                 54 => [:jump_if, [[{:random, 1..10}, "<", 7], "TOUCH"]],
                                                 55 => [:move, [{:state_variable, :facing}]],
                                                 56 => [:go, [{:state_variable, :facing}]],
                                                 57 => [:try, [{:state_variable, :facing}]],
                                                 58 => [:change_other_state, [[:event_sender], :health, "=", 1]],
                                                 59 => [:change_other_state, ["north", :blocking, "=", true]],
                                                 60 => [:change_other_state, [12345, :pullable, "=", false]],
                                                 61 => [:change_other_state, [{:state_variable, :facing}, :health, "-=", 10]],
                                                 62 => [:passage, [{:state_variable, :background_color}]],
                                                 63 => [:transport, [[:event_sender], "up"]],
                                                 64 => [:transport, [{:state_variable, :target_player}, 2, "red"]],
                                                 65 => [:text, ["buy some more", "buy"]],
                                                 66 => [:random, ["dir", "NORTH", "SOUTH", "PLAYER"]],
                                                 67 => [:sequence, ["c", "<", "^", ">", "v"]],
                                                 68 => [:jump_if, [{:state_variable, :ok}, 3]],
                                                 69 => [:jump_if, [{:state_variable, :notok}]],
                                                 70 => [:target_player, ["nearest"]],
                                                 },
                                 status: :alive,
                                 pc: 1,
                                 labels: %{"already_open" => [[7, true]], "touch" => [[2, true],[22,true]], "alreadyhave" => [[45, true]]},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}

      # Check that the parsed stuff matches the command signatures. Kinda a kludge, but no other better place for this check
      # without duplicating a bunch of other stuff
      map_instance = insert_stubbed_dungeon_instance()
      map_tile_params = %MapTile{map_instance_id: map_instance.id, id: 123, row: 1, col: 2, z_index: 0, character: ".", script: script}
      {map_tile, state} = Instances.create_map_tile(%Instances{}, map_tile_params)

      runner_state = %Runner{object_id: map_tile.id, program: program, state: state}

      assert  program.instructions
              |> Map.to_list
              |> Enum.map(fn {_line_number, [command, params]} ->
                   try do
                     apply(Command, command, [runner_state, params])
                     :ok
                   rescue
                     e in FunctionClauseError -> [Map.take(e,[:function, :module]), command, params]
                   end
                 end )
                 |> Enum.reject(fn e -> e == :ok end)
                 |> Enum.map(fn e -> inspect e end)
                 |> Enum.join("\n") == ""
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
      assert {:error, "Invalid change_state setting: `$blabel = 9`", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "a bad instance state setting" do
      script = """
               @@$blabel = 9
               """
      assert {:error, "Invalid change_instance_state setting: `$blabel = 9`", program = %Program{}} = Parser.parse(script)
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
               @@thing + 2049
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

    test "a bad other state setting" do
      script = """
               ?north@h + 9
               """
      assert {:error, "Invalid state assignment: ` + 9`", program = %Program{}} = Parser.parse(script)
      assert program == %Program{instructions: %{},
                                 status: :dead,
                                 pc: 1,
                                 labels: %{},
                                 locked: false,
                                 broadcasts: [],
                                 responses: []}
    end

    test "a bad other state assignment" do
      script = """
               ?north@ = 9
               """
      assert {:error, "Invalid :change_other_state setting: `?north@` by ` = 9`", program = %Program{}} = Parser.parse(script)
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

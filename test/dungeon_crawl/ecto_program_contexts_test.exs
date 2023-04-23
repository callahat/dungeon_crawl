defmodule DungeonCrawl.EctoProgramContextsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoProgramContexts

  @instructions_with_tuple_params %{
    1 => [:jump_if, [{:state_variable, :fuse_lit}, "FUSE_LIT"]],
    2 => [:halt, [""]],
    3 => [:noop, "TOUCH"],
    4 => [:zap, ["TOUCH"]],
    5 => [:jump_if, [{:event_sender_variable, :player}, "FUSE_LIT"]],
    6 => [:restore, ["TOUCH"]],
    7 => [:halt, [""]],
    8 => [:noop, "FUSE_LIT"],
    9 => [:zap, ["TOUCH"]],
    10 => [:jump_if, [{:state_variable, :owner}, 1]],
    11 => [:change_state, [:owner, "=", {:event_sender_variable, :id}]],
    12 => [:become, [%{character: {:state_variable, :counter}}]],
    13 => [:text, [["Ssssss....."]]],
    14 => [:noop, "TOP"],
    15 => [:compound_move, [{"idle", false}, {"idle", false}]],
    16 => [:change_state, [:counter, "-=", 1]],
    17 => [:become, [%{character: {:state_variable, :counter}}]],
    18 => [:jump_if, [[{:state_variable, :counter}, "<=", 0], "BOOM"]],
    19 => [:send_message, ["TOP"]],
    20 => [:halt, [""]],
    21 => [:noop, "BOMBED"],
    22 => [:change_state, [:owner, "=", {:event_sender_variable, :owner}]],
    23 => [:noop, "BOOM"],
    24 => [:sound, ["bomb"]],
    25 => [
      :put,
      [
        %{
          damage: {:state_variable, :bomb_damage},
          owner: {:state_variable, :owner},
          range: 6,
          shape: "circle",
          slug: "explosion"
        }
      ]
    ],
    26 => [:die, [""]]
  }

  @instructions_with_encoded_params %{
    1 => [:jump_if, [["__TUPLE__", :state_variable, :fuse_lit], "FUSE_LIT"]],
    2 => [:halt, [""]],
    3 => [:noop, "TOUCH"],
    4 => [:zap, ["TOUCH"]],
    5 => [:jump_if, [["__TUPLE__", :event_sender_variable, :player], "FUSE_LIT"]],
    6 => [:restore, ["TOUCH"]],
    7 => [:halt, [""]],
    8 => [:noop, "FUSE_LIT"],
    9 => [:zap, ["TOUCH"]],
    10 => [:jump_if, [["__TUPLE__", :state_variable, :owner], 1]],
    11 => [:change_state, [:owner, "=", ["__TUPLE__", :event_sender_variable, :id]]],
    12 => [:become, [%{character: ["__TUPLE__", :state_variable, :counter]}]],
    13 => [:text, [["Ssssss....."]]],
    14 => [:noop, "TOP"],
    15 => [:compound_move, [["__TUPLE__", "idle", false], ["__TUPLE__", "idle", false]]],
    16 => [:change_state, [:counter, "-=", 1]],
    17 => [:become, [%{character: ["__TUPLE__", :state_variable, :counter]}]],
    18 => [:jump_if, [[["__TUPLE__", :state_variable, :counter], "<=", 0], "BOOM"]],
    19 => [:send_message, ["TOP"]],
    20 => [:halt, [""]],
    21 => [:noop, "BOMBED"],
    22 => [:change_state, [:owner, "=", ["__TUPLE__", :event_sender_variable, :owner]]],
    23 => [:noop, "BOOM"],
    24 => [:sound, ["bomb"]],
    25 => [
      :put,
      [
        %{
          damage: ["__TUPLE__", :state_variable, :bomb_damage],
          owner: ["__TUPLE__", :state_variable, :owner],
          range: 6,
          shape: "circle",
          slug: "explosion"
        }
      ]
    ],
    26 => [:die, [""]]
  }

  @valid_program_context %{
    3 => %{
      event_sender: nil,
      object_id: 3,
      program: %DungeonCrawl.Scripting.Program{
        broadcasts: [],
        instructions: %{1 => [:halt, [""]]},
        labels: %{},
        lc: 0,
        locked: false,
        messages: [],
        pc: 0,
        responses: [],
        status: :idle,
        wait_cycles: 0
      }
    },
    3571817 => %{
      event_sender: nil,
      object_id: 3571817,
      program: %DungeonCrawl.Scripting.Program{
        broadcasts: [],
        instructions: @instructions_with_tuple_params,
        labels: %{
          "bombed" => [[21, true]],
          "boom" => [[23, true]],
          "fuse_lit" => [[8, true]],
          "top" => [[14, true]],
          "touch" => [[3, true]]
        },
        lc: 8,
        locked: false,
        messages: [],
        pc: 0,
        responses: [],
        status: :active,
        wait_cycles: 0
      }
    }
  }

  describe "type" do
    assert EctoProgramContexts.type == :jsonb
  end

  describe "cast/1" do
    test "returns error when its invalid" do
      assert EctoProgramContexts.cast("junk") == :error
      assert EctoProgramContexts.cast(%{123 => %{junk: "noprogram"}}) == :error
    end

    test "returns ok when empty" do
      assert EctoProgramContexts.cast(nil) == {:ok, %{}}
      assert EctoProgramContexts.cast(%{}) == {:ok ,%{}}
    end

    test "returns ok and tuple params when instructions have valid tuple params" do
      assert {:ok, program_context} = EctoProgramContexts.cast(@valid_program_context)
      assert %{3 => context_3, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context[3]

      assert context_3571817.program ==
               %{@valid_program_context[3571817].program | instructions: @instructions_with_tuple_params}
    end

    test "returns ok and tuples the params when instructions have valid encoded tuple params" do
      db_program_context = %{
        3 => @valid_program_context[3],
        3571817 => %{
          @valid_program_context[3571817] |
          program: %{@valid_program_context[3571817].program |
            instructions: @instructions_with_encoded_params}
        }
      }

      assert {:ok, program_context} = EctoProgramContexts.cast(db_program_context)
      assert %{3 => context_3, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context[3]

      assert context_3571817.program ==
               %{@valid_program_context[3571817].program | instructions: @instructions_with_tuple_params}
    end
  end

  describe "load/1" do
    test "doesnt load corrupt data" do
      assert EctoProgramContexts.load(nil) == :error
      assert EctoProgramContexts.load("someone edited this...") == :error
      assert EctoProgramContexts.load(%{123 => %{junk: "noprogram"}}) == :error
    end

    test "loads data that should have any tuples encoded" do
      assert EctoProgramContexts.load(%{}) == {:ok ,%{}}

      db_program_context = %{
        3 => @valid_program_context[3],
        3571817 => %{
          @valid_program_context[3571817] |
          program: %{@valid_program_context[3571817].program |
            instructions: @instructions_with_encoded_params}
        }
      }

      assert {:ok, program_context} = EctoProgramContexts.load(db_program_context)
      assert %{3 => context_3, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context[3]

      assert context_3571817.program ==
               %{db_program_context[3571817].program | instructions: @instructions_with_tuple_params}
      assert Map.delete(context_3571817, :program) == Map.delete(db_program_context[3571817], :program)
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert EctoProgramContexts.dump("someone edited this...") == :error
      assert EctoProgramContexts.dump([%{1 => "key"}]) == :error
    end

    test "returns ok when empty" do
      assert EctoProgramContexts.dump(nil) == {:ok, %{}}
      assert EctoProgramContexts.dump(%{}) == {:ok ,%{}}
    end

    test "returns ok and encodes the params when instructions have valid tuple params" do
      assert {:ok, program_context} = EctoProgramContexts.dump(@valid_program_context)
      assert %{3 => context_3, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context[3]

      assert context_3571817.program ==
               %{@valid_program_context[3571817].program | instructions: @instructions_with_encoded_params}
    end

    test "returns ok and encoded params when instructions have valid encoded tuple params" do
      db_program_context = %{
        3 => @valid_program_context[3],
        3571817 => %{
          @valid_program_context[3571817] |
          program: %{@valid_program_context[3571817].program |
            instructions: @instructions_with_encoded_params}
        }
      }

      assert {:ok, program_context} = EctoProgramContexts.dump(db_program_context)
      assert %{3 => context_3, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context[3]

      assert context_3571817.program ==
               %{@valid_program_context[3571817].program | instructions: @instructions_with_encoded_params}
    end
  end
end

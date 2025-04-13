defmodule DungeonCrawl.EctoProgramContextsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoProgramContexts
  alias DungeonCrawl.Player.Location

  @valid_program_context_elixir %{
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
        wait_cycles: 0,
        timed_messages: []
      }
    },
    4 => %{
      event_sender: %Location{
        user_id_hash: "testing",
        tile_instance_id: 472236
      },
      object_id: 4,
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
        wait_cycles: 0,
        timed_messages: []
      }
    },
    3571817 => %{
      event_sender: %DungeonCrawl.Player.Location{
        id: 3177,
        name: "Doc",
        state: %{
          "already_touched" => false,
          "ammo" => 6,
          "blocking" => true,
          "bullet_damage" => 10,
          "cash" => 0,
          "equipment" => ["gun"],
          "equipped" => "gun",
          "gems" => 0,
          "health" => 100,
          "lives" => -1,
          "player" => true,
          "pushable" => true,
          "score" => 0,
          "soft" => true,
          "starting_equipment" => ["gun"],
          "steps" => 13,
          "torches" => 0
        },
        tile_instance_id: 3572819,
        user_id_hash: "9fqSkIyUEajmy60SE5N4T6wvR6Dc7SL0"
      },
      object_id: 3571817,
      program: %DungeonCrawl.Scripting.Program{
        broadcasts: [],
        instructions: %{
          1 => [:jump_if, [{:state_variable, "fuse_lit"}, "FUSE_LIT"]],
          2 => [:halt, [""]],
          3 => [:noop, "TOUCH"],
          4 => [:zap, ["TOUCH"]],
          5 => [:jump_if, [{:event_sender_variable, "player"}, "FUSE_LIT"]],
          6 => [:restore, ["TOUCH"]],
          7 => [:halt, [""]],
          8 => [:noop, "FUSE_LIT"],
          9 => [:zap, ["TOUCH"]],
          10 => [:jump_if, [{:state_variable, "owner"}, 1]],
          11 => [:change_state, ["owner", "=", {:event_sender_variable, "id"}]],
          12 => [:become, [%{"character" => {:state_variable, "counter"}}]],
          13 => [:text, [["Ssssss....."]]],
          14 => [:noop, "TOP"],
          15 => [:compound_move, [{"idle", false}, {"idle", false}]],
          16 => [:change_state, ["counter", "-=", 1]],
          17 => [:become, [%{"character" => {:state_variable, "counter"}}]],
          18 => [:jump_if, [[{:state_variable, "counter"}, "<=", 0], "BOOM"]],
          19 => [:send_message, ["TOP"]],
          20 => [:halt, [""]],
          21 => [:noop, "BOMBED"],
          22 => [:change_state, ["owner", "=", {:event_sender_variable, "owner"}]],
          23 => [:noop, "BOOM"],
          24 => [:sound, ["bomb"]],
          25 => [
            :put,
            [
              %{
                "damage" => {:state_variable, "bomb_damage"},
                "owner" => {:state_variable, "owner"},
                "range" => 6,
                "shape" => "circle",
                "slug" => "explosion"
              }
            ]
          ],
          26 => [:die, [""]]
        },
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
        wait_cycles: 0,
        timed_messages: [
          {
            DateTime.from_unix!(1_694_796_368),
            "fuse_lit",
            %{
              "state" => %{
                "harvestable" => false
              },
              "tile_id" => 3571817
            }
          },
          {
            DateTime.from_unix!(1_694_999_368),
            "fuse_lit",
            %{
              "user_id_hash" => "testing",
              "tile_instance_id" => 472236,
              "state" => nil,
              "name" => nil
            }
          }
        ]
      }
    }
  }

  # Coming back from the DB, it will be an elixir map however key will be strings,
  # and atoms would be converted to strings so they are instead converted into a list with
  # "__ATOM__" as the first value, and the atom stringified as the scond value. Tuples also
  # have to be similarly encoded as JSON has no tuple, and throws an error instead of coercing
  # it into an array.
  @valid_program_context_from_json %{
    "3" => %{
      "event_sender" => nil,
      "object_id" => 3,
      "program" => %{
        "broadcasts" => [],
        "instructions" => %{"1" => [["__ATOM__", "halt"], [""]]},
        "labels" => %{},
        "lc" => 0,
        "locked" => false,
        "messages" => [],
        "pc" => 0,
        "responses" => [],
        "status" => ["__ATOM__", "idle"],
        "wait_cycles" => 0,
        "timed_messages" => []
      }
    },
    "4" => %{
      "event_sender_player_location" => %{
        "id" => nil,
        "name" => nil,
        "state" => nil,
        "tile_instance_id" => 472236,
        "user_id_hash" => "testing"
      },
      "object_id" => 4,
      "program" => %{
        "broadcasts" => [],
        "instructions" => %{
          "1" => [["__ATOM__", "halt"], [""]]
        },
        "labels" => %{},
        "lc" => 0,
        "locked" => false,
        "messages" => [],
        "pc" => 0,
        "responses" => [],
        "status" => ["__ATOM__", "idle"],
        "timed_messages" => [],
        "wait_cycles" => 0
      }
    },
    "3571817" => %{
      "event_sender_player_location" => %{
        "id" => 3177,
        "name" => "Doc",
        "state" => %{
          "already_touched" => false,
          "ammo" => 6,
          "blocking" => true,
          "bullet_damage" => 10,
          "cash" => 0,
          "equipment" => ["gun"],
          "equipped" => "gun",
          "gems" => 0,
          "health" => 100,
          "lives" => -1,
          "player" => true,
          "pushable" => true,
          "score" => 0,
          "soft" => true,
          "starting_equipment" => ["gun"],
          "steps" => 13,
          "torches" => 0
        },
        "tile_instance_id" => 3572819,
        "user_id_hash" => "9fqSkIyUEajmy60SE5N4T6wvR6Dc7SL0"
      },
      "object_id" => 3571817,
      "program" => %{
        "broadcasts" => [],
        "instructions" => %{
          "1" => [["__ATOM__", "jump_if"], [["__TUPLE__", ["__ATOM__", "state_variable"], "fuse_lit"], "FUSE_LIT"]],
          "2" => [["__ATOM__", "halt"], [""]],
          "3" => [["__ATOM__", "noop"], "TOUCH"],
          "4" => [["__ATOM__", "zap"], ["TOUCH"]],
          "5" => [["__ATOM__", "jump_if"], [["__TUPLE__", ["__ATOM__", "event_sender_variable"], "player"], "FUSE_LIT"]],
          "6" => [["__ATOM__", "restore"], ["TOUCH"]],
          "7" => [["__ATOM__", "halt"], [""]],
          "8" => [["__ATOM__", "noop"], "FUSE_LIT"],
          "9" => [["__ATOM__", "zap"], ["TOUCH"]],
          "10" => [["__ATOM__", "jump_if"], [["__TUPLE__", ["__ATOM__", "state_variable"], "owner"], 1]],
          "11" => [["__ATOM__", "change_state"], ["owner", "=", ["__TUPLE__", ["__ATOM__", "event_sender_variable"], "id"]]],
          "12" => [["__ATOM__", "become"], [%{"character" => ["__TUPLE__", ["__ATOM__", "state_variable"], "counter"]}]],
          "13" => [["__ATOM__", "text"], [["Ssssss....."]]],
          "14" => [["__ATOM__", "noop"], "TOP"],
          "15" => [["__ATOM__", "compound_move"], [["__TUPLE__", "idle", false], ["__TUPLE__", "idle", false]]],
          "16" => [["__ATOM__", "change_state"], ["counter", "-=", 1]],
          "17" => [["__ATOM__", "become"], [%{"character" => ["__TUPLE__", ["__ATOM__", "state_variable"], "counter"]}]],
          "18" => [["__ATOM__", "jump_if"], [[["__TUPLE__", ["__ATOM__", "state_variable"], "counter"], "<=", 0], "BOOM"]],
          "19" => [["__ATOM__", "send_message"], ["TOP"]],
          "20" => [["__ATOM__", "halt"], [""]],
          "21" => [["__ATOM__", "noop"], "BOMBED"],
          "22" => [["__ATOM__", "change_state"], ["owner", "=", ["__TUPLE__", ["__ATOM__", "event_sender_variable"], "owner"]]],
          "23" => [["__ATOM__", "noop"], "BOOM"],
          "24" => [["__ATOM__", "sound"], ["bomb"]],
          "25" => [
            ["__ATOM__", "put"],
            [
              %{
                "damage" => ["__TUPLE__", ["__ATOM__", "state_variable"], "bomb_damage"],
                "owner" => ["__TUPLE__", ["__ATOM__", "state_variable"], "owner"],
                "range" => 6,
                "shape" => "circle",
                "slug" => "explosion"
              }
            ]
          ],
          "26" => [["__ATOM__", "die"], [""]]
        },
        "labels" => %{
          "bombed" => [[21, true]],
          "boom" => [[23, true]],
          "fuse_lit" => [[8, true]],
          "top" => [[14, true]],
          "touch" => [[3, true]]
        },
        "lc" => 8,
        "locked" => false,
        "messages" => [],
        "pc" => 0,
        "responses" => [],
        "status" => ["__ATOM__", "active"],
        "wait_cycles" => 0,
        "timed_messages" => [
          [
            "__TUPLE__",
            %{
              "day" => 15,
              "hour" => 16,
              "year" => 2023,
              "month" => 9,
              "minute" => 46,
              "second" => 8,
              "calendar" => ["__ATOM__", "Elixir.Calendar.ISO"],
              "time_zone" => "Etc/UTC",
              "zone_abbr" => "UTC",
              "std_offset" => 0,
              "utc_offset" => 0,
              "microsecond" => ["__TUPLE__", 0, 0]
            },
            "fuse_lit",
            %{
              "state" => %{
                "harvestable" => false
              },
              "tile_id" => 3571817
            }
          ],
          [
            "__TUPLE__",
            %{
              "day" => 18,
              "hour" => 01,
              "year" => 2023,
              "month" => 9,
              "minute" => 9,
              "second" => 28,
              "calendar" => ["__ATOM__", "Elixir.Calendar.ISO"],
              "time_zone" => "Etc/UTC",
              "zone_abbr" => "UTC",
              "std_offset" => 0,
              "utc_offset" => 0,
              "microsecond" => ["__TUPLE__", 0, 0]
            },
            "fuse_lit",
            %{
              "user_id_hash" => "testing",
              "tile_instance_id" => 472236,
              "state" => nil,
              "name" => nil
            }
          ]
        ]
      }
    }
  }

  describe "type" do
    assert EctoProgramContexts.type == :jsonb
  end

  describe "cast/1" do
    test "returns error when its invalid" do
      assert EctoProgramContexts.cast("junk") == :error
      assert EctoProgramContexts.cast([]) == :error
      assert EctoProgramContexts.cast(%{123 => ["__TUPLE__", "A"], "456" => {"C","D"}})
             == :error
      assert EctoProgramContexts.cast(%{123 => ["__ATOM__", "A"]})
             == :error
    end

    test "returns ok when empty" do
      assert EctoProgramContexts.cast(nil) == {:ok, %{}}
      assert EctoProgramContexts.cast(%{}) == {:ok ,%{}}
    end

    test "returns ok and the elixir map when given an elixir map" do
      assert {:ok, program_context} = EctoProgramContexts.cast(@valid_program_context_elixir)
      assert %{3 => context_3, 4 => context_4, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context_elixir[3]
      assert context_4 == @valid_program_context_elixir[4]

      assert context_3571817 == @valid_program_context_elixir[3571817]
    end

    test "returns ok and converts it back into elixir when given something from parsed JSON" do
      assert {:ok, program_context} = EctoProgramContexts.cast(@valid_program_context_from_json)
      assert %{3 => context_3, 4 => context_4, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context_elixir[3]
      assert context_4 == @valid_program_context_elixir[4]

      assert context_3571817 == @valid_program_context_elixir[3571817]
    end
  end

  describe "load/1" do
    test "doesnt load corrupt data" do
      assert EctoProgramContexts.load(nil) == :error
      assert EctoProgramContexts.load("someone edited this...") == :error
      assert EctoProgramContexts.load(%{123 => %{junk: "noprogram"}}) == :error
    end

    test "loads empty ok" do
      assert EctoProgramContexts.load(%{}) == {:ok ,%{}}
    end


    test "loads data that is json encoded" do
      assert {:ok, program_context} = EctoProgramContexts.load(@valid_program_context_from_json)
      assert %{3 => context_3, 4 => context_4, 3571817 => context_3571817} = program_context

      assert context_3 == @valid_program_context_elixir[3]
      assert context_4 == @valid_program_context_elixir[4]
      assert context_3571817 == @valid_program_context_elixir[3571817]
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert EctoProgramContexts.dump("someone edited this...") == :error
      assert EctoProgramContexts.dump([%{1 => "key"}]) == :error
      assert EctoProgramContexts.dump(%{"1" => :atom}) == :error
      assert EctoProgramContexts.dump(%{"2" => {:one, :two}}) == :error
    end

    test "returns ok when empty" do
      assert EctoProgramContexts.dump(nil) == {:ok, %{}}
      assert EctoProgramContexts.dump(%{}) == {:ok ,%{}}
    end

    test "returns ok and the ready for json map when given the elixir map" do
      assert {:ok, program_context} = EctoProgramContexts.dump(@valid_program_context_elixir)
      assert %{"3" => context_3, "4" => context_4, "3571817" => context_3571817} = program_context

      assert context_3 == @valid_program_context_from_json["3"]
      assert context_4 == @valid_program_context_from_json["4"]
      assert context_3571817 == @valid_program_context_from_json["3571817"]
    end

    test "returns ok and the ready for json map when given the json map" do
      assert {:ok, program_context} = EctoProgramContexts.dump(@valid_program_context_from_json)
      assert %{"3" => context_3, "4" => context_4, "3571817" => context_3571817} = program_context

      assert context_3 == @valid_program_context_from_json["3"]
      assert context_4 == @valid_program_context_from_json["4"]
      assert context_3571817 == @valid_program_context_from_json["3571817"]
    end
  end
end

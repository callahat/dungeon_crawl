defmodule DungeonCrawl.Scripting.VariableResolutionTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.VariableResolution

  describe "resolve_variable" do
    test "resolves state_variable" do
      Equipment.Seeder.gun()

      dungeon_instance = insert_stubbed_dungeon_instance(%{state: "di_thing1: 999, di_flag: false"})
      {tile_1, state} = Levels.create_tile(%Levels{state_values: %{rows: 20, cols: 40},
                                                                 dungeon_instance_id: dungeon_instance.id},
                                                      %Tile{id: 1, row: 1, col: 1, color: "red", background_color: "gray", state: "red_key: 1, facing: west, point: north, equipped: gun, equipment: gun"})
      {tile_2, state} = Levels.create_tile(state,
                          %Tile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X", name: "two", background_color: "red"})

      state = %{ state | state_values: Map.merge(state.state_values, %{flag1: true, flash: "fire"})}

      runner_state1 = %Runner{state: state, object_id: tile_1.id, event_sender: tile_2}
      runner_state2 = %Runner{state: state, object_id: tile_2.id}

      # color, background_color, name and character are taken from the tile attribute
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :id}) == 1
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :color}) == "red"
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :background_color}) == "gray"
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :name}) == "two"
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :character}) == "X"
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :row}) == 0
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :col}) == 1

      # other values are taken from the state, no state value nil is returned
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :pass}) == nil
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :pass}) == "bob"

      # equipped / equipment
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :equipped}) == "gun"
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :equipment}) == ["gun"]

      # variables can be obtained from the event sender map (which will only contain tile_id and parsed_state)
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :pass}) == "bob"
      assert VariableResolution.resolve_variable(%{ runner_state1 | event_sender: %{tile_id: 123}}, {:event_sender_variable, :id}) == 123

      # no event sender no problem
      assert VariableResolution.resolve_variable(runner_state2, {:event_sender_variable, :color}) == nil

      # can get state variables from a tile in a direction, doesnt break when to tile or no value
      assert VariableResolution.resolve_variable(runner_state1, {{:direction, "north"}, :character}) == "X"
      assert VariableResolution.resolve_variable(runner_state1, {{:direction, "north"}, :foobar}) == nil
      assert VariableResolution.resolve_variable(runner_state1, {{:direction, "south"}, :character}) == nil

      # can get state variables from a tile in a direction relative to current facing, doesnt break when to tile or no value
      assert VariableResolution.resolve_variable(runner_state1, {{:direction, "clockwise"}, :character}) == "X"
      assert VariableResolution.resolve_variable(runner_state1, {{:direction, "clockwise"}, :foobar}) == nil

      # can get state variables from a tile in a direction specified by a state value, doesnt break when to tile or no value
      assert VariableResolution.resolve_variable(runner_state1, {{:state_variable, :point}, :character}) == "X"
      assert VariableResolution.resolve_variable(runner_state1, {{:state_variable, :point}, :foobar}) == nil
      assert VariableResolution.resolve_variable(runner_state1, {{:state_variable, :derp}, :character}) == nil

      # can also get an instance_state_value
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :flash}) == "fire"
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :flag1}) == true
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :notavariable}) == nil
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :north_edge}) == 0
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :west_edge}) == 0
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :east_edge}) == 39
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :south_edge}) == 19

      # can get a dungeon_instance_state_value
      assert VariableResolution.resolve_variable(runner_state1, {:dungeon_instance_state_variable, :di_thing1}) == 999
      assert VariableResolution.resolve_variable(runner_state1, {:dungeon_instance_state_variable, :di_flag}) == false

      # handles a concatenation
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :color, "_key"}) == "red_key"
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :pass, "_key"}) == "bob_key"
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :name}) == "two"
      assert VariableResolution.resolve_variable(runner_state2, {:event_sender_variable, :color, "_key"}) == nil

      # handles range
      assert VariableResolution.resolve_variable(runner_state1, {2, :distance}) == 1.0
      assert VariableResolution.resolve_variable(runner_state2, {{:state_variable, :id}, :distance}) == 0.0

      # handles random range
      rnd = VariableResolution.resolve_variable(runner_state1, {:random, 1..10})
      assert rnd >= 1
      assert rnd <= 10
    end
  end

  describe "resolve_keyed_variable" do
    test "resolves keyed_variable that might have specific format/size" do
      {tile_1, state} = Levels.create_tile(%Levels{state_values: %{rows: 20, cols: 40}},
                          %Tile{id: 1, row: 1, col: 1, color: "red", background_color: "gray", state: "newcolor: teal"})

      runner_state1 = %Runner{state: state, object_id: tile_1.id}
      var = {:state_variable, :newcolor}

      assert VariableResolution.resolve_keyed_variable(runner_state1, :color, var) == {:color, "teal"}
      assert VariableResolution.resolve_keyed_variable(runner_state1, :character, var) == {:character, "t"}
    end
  end

  describe "resolve_variables" do
    test "resolves a list of variables" do
      {tile_1, state} = Levels.create_tile(%Levels{}, %Tile{id: 1, row: 1, col: 1, color: "red", background_color: "gray"})
      {tile_2, state} = Levels.create_tile(state, %Tile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X"})

      state = %{ state | state_values: %{flag1: true, flash: "fire"}}

      runner_state1 = %Runner{state: state, object_id: tile_1.id, event_sender: Map.put(%Location{id: 123, tile_instance_id: tile_2.id}, :parsed_state, tile_2.parsed_state)}

      variable_list = ["nothing done",
                       {:state_variable, :color},
                       {:state_variable, :pass},
                       {:event_sender_variable, :id},
                       [:event_sender],
                       {:event_sender_variable, :pass},
                       {{:direction, "north"}, :character},
                       {:instance_state_variable, :flag1}]

      expected = ["nothing done",
                  "red",
                  nil,
                  tile_2.id,
                  tile_2.id,
                  "bob",
                  "X",
                  true]

      assert VariableResolution.resolve_variables(runner_state1, variable_list) == expected
    end

    test "resolves a map of variables" do
      {tile_1, state} = Levels.create_tile(%Levels{}, %Tile{id: 1, row: 1, col: 1, color: "red", background_color: "gray"})
      {tile_2, state} = Levels.create_tile(state, %Tile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X"})

      state = %{ state | state_values: %{flag1: true, flash: "fire"}}

      runner_state1 = %Runner{state: state, object_id: tile_1.id, event_sender: tile_2}

      variable_map = %{literal: "nothing done",
                       state_var_1: {:state_variable, :color},
                       state_var_2: {:state_variable, :pass},
                       event_sender_id: {:event_sender_variable, :id},
                       event_sender_id2: [:event_sender],
                       event_sender: {:event_sender_variable, :pass},
                       directional: {{:direction, "north"}, :character},
                       instance: {:instance_state_variable, :flag1}}

      expected = %{literal: "nothing done",
                       state_var_1: "red",
                       state_var_2: nil,
                       event_sender_id: tile_2.id,
                       event_sender_id2: tile_2.id,
                       event_sender: "bob",
                       directional: "X",
                       instance: true}

      assert VariableResolution.resolve_variables(runner_state1, variable_map) == expected
    end
  end

  describe "special resolutions" do
    test "?any_player@is_facing returns true if the object is directly facing a player" do
      {fake_player, state} = Levels.create_player_tile(%Levels{}, %Tile{id: 2, row: 4, col: 2, character: "@"}, %Location{})
      {tile_1, state} = Levels.create_tile(state, %Tile{id: 1, row: 4, col: 4, character: "?", state: "facing: west"})
      runner_state1 = %Runner{state: state, object_id: tile_1.id}
      assert VariableResolution.resolve_variable(runner_state1, {:any_player, :is_facing})

      {_fake_player, state} = Levels.update_tile(state, fake_player, %{row: 3})
      runner_state1 = %Runner{state: state, object_id: tile_1.id}
      refute VariableResolution.resolve_variable(runner_state1, {:any_player, :is_facing})
    end

    test "?{ @target_player_tile_id }@is_facing returns true if the object is directly facing targeted player" do
      {_fake_player, state} = Levels.create_player_tile(%Levels{}, %Tile{id: 1, row: 4, col: 2, character: "@"}, %Location{})
      {_other_fake_player, state} = Levels.create_player_tile(state, %Tile{id: 2, row: 1, col: 4, character: "@"}, %Location{})
      {tile_1, state} = Levels.create_tile(state, %Tile{id: 3, row: 4, col: 4, character: "?", state: "facing: west, target_player_map_tile_id: 1"})
      runner_state1 = %Runner{state: state, object_id: tile_1.id}
      assert VariableResolution.resolve_variable(runner_state1, {{:state_variable, :target_player_map_tile_id}, :is_facing})
      # also works with ID, as the above resolves to it at run time
      assert VariableResolution.resolve_variable(runner_state1, {1, :is_facing})
      refute VariableResolution.resolve_variable(runner_state1, {2, :is_facing})
    end
  end
end

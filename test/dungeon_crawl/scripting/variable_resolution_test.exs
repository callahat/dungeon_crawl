defmodule DungeonCrawl.Scripting.VariableResolutionTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.VariableResolution

  # TODO

  describe "resolve_variable" do
    test "resolves state_variable" do
      {map_tile_1, state} = Instances.create_map_tile(%Instances{},
                              %MapTile{id: 1, row: 1, col: 1, color: "red", background_color: "gray", state: "red_key: 1, facing: west, point: north"})
      {map_tile_2, state} = Instances.create_map_tile(state,
                              %MapTile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X", name: "two", background_color: "red"})

      state = %{ state | state_values: %{flag1: true, flash: "fire"}}

      runner_state1 = %Runner{state: state, object_id: map_tile_1.id, event_sender: map_tile_2}
      runner_state2 = %Runner{state: state, object_id: map_tile_2.id}

      # color, background_color, name and character are taken from the map_tile attribute
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :color}) == "red"
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :background_color}) == "gray"
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :name}) == "two"
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :character}) == "X"

      # other values are taken from the state, no state value nil is returned
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :pass}) == nil
      assert VariableResolution.resolve_variable(runner_state2, {:state_variable, :pass}) == "bob"

      # variables can be obtained from the event sender map (which will only contain map_tile_id and parsed_state)
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :pass}) == "bob"

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

      # handles a concatenation
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :color, "_key"}) == "red_key"
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :pass, "_key"}) == "bob_key"
      assert VariableResolution.resolve_variable(runner_state2, {:event_sender_variable, :color, "_key"}) == nil
    end
  end

  describe "resolve_variable_map" do
    test "resolves a map of variables" do
      {map_tile_1, state} = Instances.create_map_tile(%Instances{}, %MapTile{id: 1, row: 1, col: 1, color: "red", background_color: "gray"})
      {map_tile_2, state} = Instances.create_map_tile(state, %MapTile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X"})

      state = %{ state | state_values: %{flag1: true, flash: "fire"}}

      runner_state1 = %Runner{state: state, object_id: map_tile_1.id, event_sender: map_tile_2}

      variable_map = %{literal: "nothing done",
                       state_var_1: {:state_variable, :color},
                       state_var_2: {:state_variable, :pass},
                       event_sender: {:event_sender_variable, :pass},
                       directional: {{:direction, "north"}, :character},
                       instance: {:instance_state_variable, :flag1}}

      expected = %{literal: "nothing done",
                       state_var_1: "red",
                       state_var_2: nil,
                       event_sender: "bob",
                       directional: "X",
                       instance: true}

      assert VariableResolution.resolve_variable_map(runner_state1, variable_map) == expected

    end
  end
end

defmodule DungeonCrawl.Scripting.VariableResolutionTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.VariableResolution

  describe "resolve_variable" do
    test "resolves state_variable" do
      {:ok, instance_process} = InstanceProcess.start_link([])

      map_tile_1 = %MapTile{id: 1, row: 1, col: 1, color: "red", background_color: "gray", state: "red_key: 1, facing: west, point: north"}
      map_tile_2 = %MapTile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X", name: "two", background_color: "red"}

      InstanceProcess.load_map(instance_process, [map_tile_1, map_tile_2])
      InstanceProcess.set_state_values(instance_process, %{rows: 20, cols: 40, flag1: true, flash: "fire"})
      map_tile_1 = InstanceProcess.get_tile(instance_process, map_tile_1.id)
      map_tile_2 = InstanceProcess.get_tile(instance_process, map_tile_2.id)

      state = InstanceProcess.get_state(instance_process)

      runner_state1 = %Runner{state: state, object_id: map_tile_1.id, event_sender: map_tile_2}
      runner_state2 = %Runner{state: state, object_id: map_tile_2.id}

      # color, background_color, name and character are taken from the map_tile attribute
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
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :north_edge}) == 0
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :west_edge}) == 0
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :east_edge}) == 39
      assert VariableResolution.resolve_variable(runner_state1, {:instance_state_variable, :south_edge}) == 19

      # handles a concatenation
      assert VariableResolution.resolve_variable(runner_state1, {:state_variable, :color, "_key"}) == "red_key"
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :pass, "_key"}) == "bob_key"
      assert VariableResolution.resolve_variable(runner_state1, {:event_sender_variable, :name}) == "two"
      assert VariableResolution.resolve_variable(runner_state2, {:event_sender_variable, :color, "_key"}) == nil

      # handles range
      assert VariableResolution.resolve_variable(runner_state1, {2, :distance}) == 1.0
      assert VariableResolution.resolve_variable(runner_state2, {{:state_variable, :id}, :distance}) == 0.0
    end
  end

  describe "resolve_keyed_variable" do
    test "resolves keyed_variable that might have specific format/size" do
      {:ok, instance_process} = InstanceProcess.start_link([])

      map_tile_1 = %MapTile{id: 1, row: 1, col: 1, color: "red", background_color: "gray", state: "newcolor: teal"}

      InstanceProcess.load_map(instance_process, [map_tile_1])
      InstanceProcess.set_state_values(instance_process, %{rows: 20, cols: 40})
      map_tile_1 = InstanceProcess.get_tile(instance_process, map_tile_1.id)

      state = InstanceProcess.get_state(instance_process)

      runner_state1 = %Runner{state: state, object_id: map_tile_1.id}
      var = {:state_variable, :newcolor}

      assert VariableResolution.resolve_keyed_variable(runner_state1, :color, var) == {:color, "teal"}
      assert VariableResolution.resolve_keyed_variable(runner_state1, :character, var) == {:character, "t"}
    end
  end

  describe "resolve_variable_map" do
    test "resolves a map of variables" do
      {:ok, instance_process} = InstanceProcess.start_link([])

      map_tile_1 = %MapTile{id: 1, row: 1, col: 1, color: "red", background_color: "gray"}
      map_tile_2 = %MapTile{id: 2, row: 0, col: 1, state: "pass: bob", character: "X"}

      InstanceProcess.load_map(instance_process, [map_tile_1, map_tile_2])
      InstanceProcess.set_state_values(instance_process, %{flag1: true, flash: "fire"})
      map_tile_1 = InstanceProcess.get_tile(instance_process, map_tile_1.id)
      map_tile_2 = InstanceProcess.get_tile(instance_process, map_tile_2.id)

      state = InstanceProcess.get_state(instance_process)

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

  describe "special resolutions" do
    test "?any_player@is_facing returns true if the object is directly facing a player" do
      {:ok, instance_process} = InstanceProcess.start_link([])

      map_tile_1 = %MapTile{id: 1, row: 4, col: 4, character: "?", state: "facing: west"}
      fake_player = %MapTile{id: 2, row: 4, col: 2, character: "@"}

      InstanceProcess.run_with(
        instance_process,
        fn state ->
          Instances.create_player_map_tile(state, fake_player, %Location{})
        end)
      InstanceProcess.load_map(instance_process, [map_tile_1])
      map_tile_1 = InstanceProcess.get_tile(instance_process, map_tile_1.id)
      fake_player = InstanceProcess.get_tile(instance_process, fake_player.id)

      state = InstanceProcess.get_state(instance_process)

      runner_state1 = %Runner{state: state, object_id: map_tile_1.id}
      assert VariableResolution.resolve_variable(runner_state1, {:any_player, :is_facing})

      {_fake_player, state} = Instances.update_map_tile(state, fake_player, %{row: 3})
      runner_state1 = %Runner{state: state, object_id: map_tile_1.id}
      refute VariableResolution.resolve_variable(runner_state1, {:any_player, :is_facing})
    end

    test "?{ @target_player_map_tile_id }@is_facing returns true if the object is directly facing targeted player" do
      {:ok, instance_process} = InstanceProcess.start_link([])

      map_tile_1 = %MapTile{id: 3, row: 4, col: 4, character: "?", state: "facing: west, target_player_map_tile_id: 1"}
      fake_player = %MapTile{id: 1, row: 4, col: 2, character: "@"}
      other_fake_player = %MapTile{id: 2, row: 1, col: 4, character: "@"}

      InstanceProcess.run_with(
        instance_process,
        fn state ->
          {_, state} = Instances.create_player_map_tile(state, fake_player, %Location{})
          Instances.create_player_map_tile(state, other_fake_player, %Location{})
        end)
      InstanceProcess.load_map(instance_process, [map_tile_1])
      map_tile_1 = InstanceProcess.get_tile(instance_process, map_tile_1.id)

      state = InstanceProcess.get_state(instance_process)

      runner_state1 = %Runner{state: state, object_id: map_tile_1.id}
      assert VariableResolution.resolve_variable(runner_state1, {{:state_variable, :target_player_map_tile_id}, :is_facing})
      # also works with ID, as the above resolves to it at run time
      assert VariableResolution.resolve_variable(runner_state1, {1, :is_facing})
      refute VariableResolution.resolve_variable(runner_state1, {2, :is_facing})
    end
  end
end

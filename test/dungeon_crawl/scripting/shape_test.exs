defmodule DungeonCrawl.Scripting.ShapeTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Shape

  setup do
    map_tiles = for row <- 0..4, col <- 0..4, do: %MapTile{id: row * 100 + col, row: row, col: col, z_index: 0, character: "."}
    state = %Instances{state_values: %{rows: 5, cols: 5}}
    state = Enum.reduce(map_tiles, state, fn(map_tile, state) -> {_, state} = Instances.create_map_tile(state, map_tile); state end)

    %{state: state}
  end

  describe "line/5" do
    test "returns coordinates in a line", %{state: state} do
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 3, true) == [{0, 2}, {1, 2}, {2, 2}, {3, 2}]
      assert Shape.line(runner_state, "south", 3) == [{1, 2}, {2, 2}, {3, 2}]

      assert Shape.line(runner_state, "north", 3, true) == [{0, 2}]
      assert Shape.line(runner_state, "north", 3) == []
    end

    test "returns coordinates in a line until blocked if bypass_blocking is true", %{state: state} do
      wall = %MapTile{id: 999, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_wall, state} = Instances.create_map_tile(state, wall)
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 3, true, true) == [{0, 2}, {1, 2}, {2, 2}, {3, 2}]
      assert Shape.line(runner_state, "south", 3, true, false) == [{0, 2}, {1, 2}]
      assert Shape.line(runner_state, "south", 3, true, "soft") == [{0, 2}, {1, 2}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %MapTile{id: 801, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall = %MapTile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Instances.create_map_tile(state, breakable_wall)
      {_, state} = Instances.create_map_tile(state, wall)
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 3, true) == [{0, 2}, {1, 2}, {2, 2}]
      assert Shape.line(runner_state, "south", 3, true, false) == [{0, 2}, {1, 2}]
    end
  end

  describe "cone/6" do
    test "returns coordinates in a cone", %{state: state} do
      runner_state = %Runner{object_id: 102, state: state}

      assert Shape.cone(runner_state, "south", 2, 2, true) == [{1, 2}, {2, 1}, {3, 0}, {3, 1}, {2, 2}, {3, 2}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2) == [{2, 1}, {3, 0}, {3, 1}, {2, 2}, {3, 2}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 3, 1) == [{2, 2}, {3, 1}, {4, 1}, {3, 2}, {4, 2}, {3, 3}, {4, 3}]

      assert Shape.cone(runner_state, "north", 2, 2, true) == [{1, 2}, {0, 1}, {0, 2}, {0, 3}]
      assert Shape.cone(runner_state, "north", 2, 2) == [{0, 1}, {0, 2}, {0, 3}]
    end

    test "returns coordinates in a cone where rays may be blocked if bypass_blocking is false", %{state: state} do
      wall = %MapTile{id: 999, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_wall, state} = Instances.create_map_tile(state, wall)
      runner_state = %Runner{object_id: 102, state: state}

      assert Shape.cone(runner_state, "south", 2, 2, true, true) == [{1, 2}, {2, 1}, {3, 0}, {3, 1}, {2, 2}, {3, 2}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2, false, false) == [{2, 1}, {3, 0}, {3, 1}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2, false, "soft") == [{2, 1}, {3, 0}, {3, 1}, {2, 3}, {3, 3}, {3, 4}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %MapTile{id: 801, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall = %MapTile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Instances.create_map_tile(state, breakable_wall)
      {_, state} = Instances.create_map_tile(state, wall)
      runner_state = %Runner{object_id: 102, state: state}

      assert Shape.cone(runner_state, "south", 2, 2) == [{2, 1}, {3, 0}, {3, 1}, {2, 2}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2, true, false) == [{1, 2}, {2, 1}, {3, 0}, {3, 1}, {2, 3}, {3, 3}, {3, 4}]
    end
  end
end

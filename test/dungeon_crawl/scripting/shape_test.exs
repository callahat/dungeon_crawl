defmodule DungeonCrawl.Scripting.ShapeTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Shape

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])

    map_tiles = for row <- 0..4, col <- 0..4, do: %MapTile{id: row * 100 + col, row: row, col: col, z_index: 0, character: "."}
    InstanceProcess.load_map(instance_process, map_tiles)
    InstanceProcess.set_state_values(instance_process, %{rows: 5, cols: 5})

    state = InstanceProcess.get_state(instance_process)

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

  describe "circle/4" do
    test "returns coordinates in a circle", %{state: state} do
      runner_state = %Runner{object_id: 202, state: state}

      assert Shape.circle(runner_state, 1, false) == [{1, 2}, {2, 1}, {2, 3}, {3, 2}]
      assert Shape.circle(runner_state, 2) ==
               [{2, 2}, {0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
    end

    test "returns coordinates in a cone where rays may be blocked if bypass_blocking is false", %{state: state} do
      wall = %MapTile{id: 999, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_wall, state} = Instances.create_map_tile(state, wall)
      runner_state = %Runner{object_id: 202, state: state}

      assert Shape.circle(runner_state, 2, true, true) ==
               [{2, 2}, {0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
      assert Shape.circle(runner_state, 2, false, false) ==
               [{0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
      assert Shape.circle(runner_state, 2, false, "soft") ==
               [{0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %MapTile{id: 801, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall = %MapTile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Instances.create_map_tile(state, breakable_wall)
      {_, state} = Instances.create_map_tile(state, wall)
      runner_state = %Runner{object_id: 202, state: state}

      assert Shape.circle(runner_state, 2) ==
               [{2, 2}, {0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
      assert Shape.circle(runner_state, 2, true, false) ==
               [{2, 2}, {0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 3}, {3, 4},
                        {4, 1}, {4, 3}]
    end
  end

  describe "blob/4" do
    test "returns coordinates in a circle", %{state: state} do
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 1, false) == [{1, 0}, {0, 1}]
      assert Shape.blob(runner_state, 2) == [{2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
    end

    test "returns coordinates in a cone where rays may be blocked if bypass_blocking is false", %{state: state} do
      wall1 = %MapTile{id: 990, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
      wall2 = %MapTile{id: 991, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %MapTile{id: 992, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %MapTile{id: 993, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall5 = %MapTile{id: 994, row: 2, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Instances.create_map_tile(state, wall1)
      {_, state} = Instances.create_map_tile(state, wall2)
      {_, state} = Instances.create_map_tile(state, wall3)
      {_, state} = Instances.create_map_tile(state, wall4)
      {_, state} = Instances.create_map_tile(state, wall5)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 2, true, true) == [{2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
      assert Shape.blob(runner_state, 2, false, false) == [{0, 2}, {0, 0}, {0, 1}]
      assert Shape.blob(runner_state, 2, false, "soft") == [{0, 2}, {0, 0}, {0, 1}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %MapTile{id: 80001, row: 0, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall1 = %MapTile{id: 90090, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
      wall2 = %MapTile{id: 90091, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %MapTile{id: 90092, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %MapTile{id: 90093, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall5 = %MapTile{id: 90094, row: 2, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Instances.create_map_tile(state, breakable_wall)
      {_, state} = Instances.create_map_tile(state, wall1)
      {_, state} = Instances.create_map_tile(state, wall2)
      {_, state} = Instances.create_map_tile(state, wall3)
      {_, state} = Instances.create_map_tile(state, wall4)
      {_, state} = Instances.create_map_tile(state, wall5)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 4, true, true) ==
        [{4, 0}, {3, 1}, {2, 2}, {1, 3}, {0, 4}, {3, 0}, {2, 1}, {1, 2}, {0, 3}, {2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
      assert Shape.blob(runner_state, 4, false, false) == [{0, 0}, {0, 1}]
      assert Shape.blob(runner_state, 4, false, "soft") == [{2, 2}, {1, 2}, {0, 2}, {0, 0}, {0, 1}]
    end
  end
end

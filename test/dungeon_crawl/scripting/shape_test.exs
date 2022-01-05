defmodule DungeonCrawl.Scripting.ShapeTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Shape

  setup do
    tiles = for row <- 0..4, col <- 0..4, do: %Tile{id: row * 100 + col, row: row, col: col, z_index: 0, character: "."}
    state = %Levels{state_values: %{rows: 5, cols: 5}}
    state = Enum.reduce(tiles, state, fn(tile, state) -> {_, state} = Levels.create_tile(state, tile); state end)

    %{state: state}
  end

  # line uses an internal function _coords_between, which is also used by most of the other shape, most
  # of the various scenarios (ie, soft but bypasses soft, tile is low but bypass blocking is once, etc)
  # can be sufficiently covered here. blob is an exception.
  describe "line/5" do
    test "returns coordinates in a line", %{state: state} do
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 3, true) == [{0, 2}, {1, 2}, {2, 2}, {3, 2}]
      assert Shape.line(runner_state, "south", 3) == [{1, 2}, {2, 2}, {3, 2}]

      assert Shape.line(runner_state, "north", 3, true) == [{0, 2}]
      assert Shape.line(runner_state, "north", 3) == []
    end

    test "returns coordinates in a line until blocked if bypass_blocking is true", %{state: state} do
      wall = %Tile{id: 999, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_wall, state} = Levels.create_tile(state, wall)
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 3, true, true) == [{0, 2}, {1, 2}, {2, 2}, {3, 2}]
      assert Shape.line(runner_state, "south", 3, true, false) == [{0, 2}, {1, 2}]
      assert Shape.line(runner_state, "south", 3, true, "soft") == [{0, 2}, {1, 2}]
      assert Shape.line(runner_state, "south", 4, true, "once") == [{0, 2}, {1, 2}, {2, 2}]
      assert Shape.line(runner_state, "south", 4, true, "visible") == [{0, 2}, {1, 2}, {2, 2}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %Tile{id: 801, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall = %Tile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, breakable_wall)
      {_, state} = Levels.create_tile(state, wall)
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 4, true) == [{0, 2}, {1, 2}, {2, 2}]
      assert Shape.line(runner_state, "south", 4, true, "soft") == [{0, 2}, {1, 2}, {2, 2}]
    end

    test "bypass_blocking value can be 'once' and does not count a low blocking tile against that once", %{state: state} do
      water = %Tile{id: 801, row: 2, col: 2, z_index: 1, character: "w", state: "blocking: true, low: true"}
      wall = %Tile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, water)
      {_, state} = Levels.create_tile(state, wall)
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 4, true, "once") == [{0, 2}, {1, 2}, {2, 2}, {3, 2}]
    end

    test "bypass_blocking value can be 'visible' which only bypasses blocking that do not block vision and the first blocking", %{state: state} do
      thing = %Tile{id: 801, row: 2, col: 2, z_index: 1, character: "-", state: "blocking: true, blocking_light: false"}
      wall = %Tile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      past_wall = %Tile{id: 803, row: 4, col: 2, z_index: 1, character: ".", state: ""}
      {_, state} = Levels.create_tile(state, thing)
      {_, state} = Levels.create_tile(state, wall)
      {_, state} = Levels.create_tile(state, past_wall)
      runner_state = %Runner{object_id: 2, state: state}

      assert Shape.line(runner_state, "south", 4, true, true) == [{0, 2}, {1, 2}, {2, 2}, {3, 2}, {4, 2}]
      assert Shape.line(runner_state, "south", 4, true, "visible") == [{0, 2}, {1, 2}, {2, 2}, {3, 2}]
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
      wall = %Tile{id: 999, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_wall, state} = Levels.create_tile(state, wall)
      runner_state = %Runner{object_id: 102, state: state}

      assert Shape.cone(runner_state, "south", 2, 2, true, true) == [{1, 2}, {2, 1}, {3, 0}, {3, 1}, {2, 2}, {3, 2}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2, false, false) == [{2, 1}, {3, 0}, {3, 1}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2, false, "soft") == [{2, 1}, {3, 0}, {3, 1}, {2, 3}, {3, 3}, {3, 4}]
      assert Shape.cone(runner_state, "south", 2, 2, false, "once") == [{2, 1}, {3, 0}, {3, 1}, {2, 2}, {2, 3}, {3, 3}, {3, 4}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %Tile{id: 801, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall = %Tile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, breakable_wall)
      {_, state} = Levels.create_tile(state, wall)
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
      wall = %Tile{id: 999, row: 2, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_wall, state} = Levels.create_tile(state, wall)
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
      assert Shape.circle(runner_state, 2, false, "once") ==
               [{0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
      tile_202 = Levels.get_tile_by_id(state, %{id: 202})
      assert Shape.circle(%{state: state, object_id: 202}, 2) == Shape.circle(%{state: state, origin: tile_202}, 2)
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %Tile{id: 801, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall = %Tile{id: 802, row: 3, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, breakable_wall)
      {_, state} = Levels.create_tile(state, wall)
      runner_state = %Runner{object_id: 202, state: state}

      assert Shape.circle(runner_state, 2) ==
               [{2, 2}, {0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 2}, {3, 3}, {3, 4},
                        {4, 1}, {4, 2}, {4, 3}]
      assert Shape.circle(runner_state, 2, true, false) ==
               [{2, 2}, {0, 1}, {0, 2}, {0, 3}, {1, 0}, {1, 1}, {1, 2}, {1, 3}, {1, 4},
                        {2, 0}, {2, 1}, {2, 3}, {2, 4}, {3, 0}, {3, 1}, {3, 3}, {3, 4}]
    end
  end

  describe "blob/4" do
    test "returns coordinates in a circle", %{state: state} do
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 1, false) == [{1, 0}, {0, 1}]
      assert Shape.blob(runner_state, 2) == [{2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
    end

    test "returns coordinates in a cone where rays may be blocked if bypass_blocking is false", %{state: state} do
      wall1 = %Tile{id: 990, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
      wall2 = %Tile{id: 991, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %Tile{id: 992, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %Tile{id: 993, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall5 = %Tile{id: 994, row: 2, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, wall1)
      {_, state} = Levels.create_tile(state, wall2)
      {_, state} = Levels.create_tile(state, wall3)
      {_, state} = Levels.create_tile(state, wall4)
      {_, state} = Levels.create_tile(state, wall5)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 2, true, true) == [{2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
      assert Shape.blob(runner_state, 2, false, false) == [{0, 2}, {0, 0}, {0, 1}]
      assert Shape.blob(runner_state, 2, false, "soft") == [{0, 2}, {0, 0}, {0, 1}]
      assert Shape.blob(runner_state, 2, false, "once") == [{1, 1}, {0, 2}, {0, 0}, {1, 0}, {0, 1}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %Tile{id: 80001, row: 0, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall1 = %Tile{id: 90090, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
      wall2 = %Tile{id: 90091, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %Tile{id: 90092, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %Tile{id: 90093, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall5 = %Tile{id: 90094, row: 2, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, breakable_wall)
      {_, state} = Levels.create_tile(state, wall1)
      {_, state} = Levels.create_tile(state, wall2)
      {_, state} = Levels.create_tile(state, wall3)
      {_, state} = Levels.create_tile(state, wall4)
      {_, state} = Levels.create_tile(state, wall5)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 4, true, true) ==
        [{4, 0}, {3, 1}, {2, 2}, {1, 3}, {0, 4}, {3, 0}, {2, 1}, {1, 2}, {0, 3}, {2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
      assert Shape.blob(runner_state, 4, false, false) == [{0, 0}, {0, 1}]
      assert Shape.blob(runner_state, 4, false, "soft") == [{2, 2}, {1, 2}, {0, 2}, {0, 0}, {0, 1}]
    end

    test "bypass_blocking value can be 'once' and does not count a low blocking tile against that once", %{state: state} do
      water1 = %Tile{id: 80001, row: 0, col: 1, z_index: 1, character: "w", state: "blocking: true, low: true"}
      water2 = %Tile{id: 90090, row: 0, col: 2, z_index: 1, character: "w", state: "blocking: true, low: true"}
      wall1 = %Tile{id: 90091, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall2 = %Tile{id: 90092, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %Tile{id: 90093, row: 1, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %Tile{id: 90094, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, water1)
      {_, state} = Levels.create_tile(state, water2)
      {_, state} = Levels.create_tile(state, wall1)
      {_, state} = Levels.create_tile(state, wall2)
      {_, state} = Levels.create_tile(state, wall3)
      {_, state} = Levels.create_tile(state, wall4)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob(runner_state, 4, true, true) ==
        [{4, 0}, {3, 1}, {2, 2}, {1, 3}, {0, 4}, {3, 0}, {2, 1}, {1, 2}, {0, 3}, {2, 0}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
      assert Shape.blob(runner_state, 4, false, false) == []
      assert Shape.blob(runner_state, 4, true, "once") == [{1, 2}, {0, 3}, {1, 1}, {0, 2}, {1, 0}, {0, 1}, {0, 0}]
    end
  end

  # Pretty much the same test as "blob", but with a distance number in the returned tuple
  describe "blob_with_range/4" do
    test "returns coordinates in a blob", %{state: state} do
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob_with_range(runner_state, 1, false) == [{1, 0, 1}, {0, 1, 1}]
      assert Shape.blob_with_range(runner_state, 2) == [{2, 0, 2}, {1, 1, 2}, {0, 2, 2}, {1, 0, 1}, {0, 1, 1}, {0, 0, 0}]
    end

    test "returns coordinates in a blob where it may be blocked if bypass_blocking is false", %{state: state} do
      wall1 = %Tile{id: 990, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
      wall2 = %Tile{id: 991, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %Tile{id: 992, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %Tile{id: 993, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall5 = %Tile{id: 994, row: 2, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, wall1)
      {_, state} = Levels.create_tile(state, wall2)
      {_, state} = Levels.create_tile(state, wall3)
      {_, state} = Levels.create_tile(state, wall4)
      {_, state} = Levels.create_tile(state, wall5)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob_with_range(runner_state, 2, true, true) == [{2, 0, 2}, {1, 1, 2}, {0, 2, 2}, {1, 0, 1}, {0, 1, 1}, {0, 0, 0}]
      assert Shape.blob_with_range(runner_state, 2, false, false) == [{0, 2, 2}, {0, 0, 2}, {0, 1, 1}]
      assert Shape.blob_with_range(runner_state, 2, false, "soft") == [{0, 2, 2}, {0, 0, 2}, {0, 1, 1}]
      assert Shape.blob_with_range(runner_state, 2, false, "once") == [{1, 1, 2}, {0, 2, 2}, {0, 0, 2}, {1, 0, 1}, {0, 1, 1}]
    end

    test "bypass_blocking value can be 'soft' which only bypasses blocking that is also soft", %{state: state} do
      breakable_wall = %Tile{id: 80001, row: 0, col: 2, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall1 = %Tile{id: 90090, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true"}
      wall2 = %Tile{id: 90091, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %Tile{id: 90092, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %Tile{id: 90093, row: 1, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      wall5 = %Tile{id: 90094, row: 2, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, breakable_wall)
      {_, state} = Levels.create_tile(state, wall1)
      {_, state} = Levels.create_tile(state, wall2)
      {_, state} = Levels.create_tile(state, wall3)
      {_, state} = Levels.create_tile(state, wall4)
      {_, state} = Levels.create_tile(state, wall5)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob_with_range(runner_state, 4, true, true) ==
               [{4, 0, 4}, {3, 1, 4}, {2, 2, 4}, {1, 3, 4}, {0, 4, 4},
                {3, 0, 3}, {2, 1, 3}, {1, 2, 3}, {0, 3, 3},
                {2, 0, 2}, {1, 1, 2}, {0, 2, 2},
                {1, 0, 1}, {0, 1, 1},
                {0, 0, 0}]
      assert Shape.blob_with_range(runner_state, 4, false, false) == [{0, 0, 2}, {0, 1, 1}]
      assert Shape.blob_with_range(runner_state, 4, false, "soft") ==
               [{2, 2, 4}, {1, 2, 3}, {0, 2, 2}, {0, 0, 2}, {0, 1, 1}]
    end

    test "bypass_blocking value can be 'once' and does not count a low blocking tile against that once", %{state: state} do
      water1 = %Tile{id: 80001, row: 0, col: 1, z_index: 1, character: "w", state: "blocking: true, low: true"}
      water2 = %Tile{id: 90090, row: 0, col: 2, z_index: 1, character: "w", state: "blocking: true, low: true"}
      wall1 = %Tile{id: 90091, row: 1, col: 0, z_index: 1, character: "#", state: "blocking: true, soft: true"}
      wall2 = %Tile{id: 90092, row: 1, col: 1, z_index: 1, character: "#", state: "blocking: true"}
      wall3 = %Tile{id: 90093, row: 1, col: 2, z_index: 1, character: "#", state: "blocking: true"}
      wall4 = %Tile{id: 90094, row: 0, col: 3, z_index: 1, character: "#", state: "blocking: true"}
      {_, state} = Levels.create_tile(state, water1)
      {_, state} = Levels.create_tile(state, water2)
      {_, state} = Levels.create_tile(state, wall1)
      {_, state} = Levels.create_tile(state, wall2)
      {_, state} = Levels.create_tile(state, wall3)
      {_, state} = Levels.create_tile(state, wall4)
      runner_state = %Runner{object_id: 0, state: state}

      assert Shape.blob_with_range(runner_state, 4, true, true) ==
               [{4, 0, 4}, {3, 1, 4}, {2, 2, 4}, {1, 3, 4}, {0, 4, 4},
                {3, 0, 3}, {2, 1, 3}, {1, 2, 3}, {0, 3, 3},
                {2, 0, 2}, {1, 1, 2}, {0, 2, 2},
                {1, 0, 1}, {0, 1, 1},
                {0, 0, 0}]
      assert Shape.blob_with_range(runner_state, 4, false, false) == []
      assert Shape.blob_with_range(runner_state, 4, true, "once") ==
               [{1, 2, 3}, {0, 3, 3},
                {1, 1, 2}, {0, 2, 2},
                {1, 0, 1}, {0, 1, 1},
                {0, 0, 0}]
    end
  end
end

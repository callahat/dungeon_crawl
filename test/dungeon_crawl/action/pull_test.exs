defmodule DungeonCrawl.Action.PullTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Pull
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.Levels

  setup _config do
    instance = insert_stubbed_level_instance(%{},
      [%Tile{character: ".", row: 1, col: 2, z_index: 0},
       %Tile{character: ".", row: 2, col: 2, z_index: 0},
       %Tile{character: "-", row: 3, col: 2, z_index: 0},
       %Tile{character: "~", row: 3, col: 3, z_index: 0},
       %Tile{character: "@", row: 2, col: 2, z_index: 1},
       %Tile{character: ".", row: 4, col: 1, z_index: 0},
       %Tile{character: ".", row: 4, col: 2, z_index: 0},
       %Tile{character: ".", row: 3, col: 1, z_index: 0}
      ])

    # Quik and dirty state init
    state = Repo.preload(instance, :tiles).tiles
            |> Enum.reduce(%Levels{}, fn(t, state) ->
                 {_, state} = Levels.create_tile(state, t)
                 state
               end)

    destination = Levels.get_tile(state, %{row: 1, col: 2})
    puller = Levels.get_tile(state, %{row: 2, col: 2})
    %{state: state, puller: puller, destination: destination}
  end

  describe "pull/3" do
    test "pulling but movement is blocked", %{state: state, puller: puller, destination: destination} do
      object           = %Tile{id: 998, row: 3, col: 2, z_index: 0, character: "X", state: "pullable: true"}
      {_object, state} = Levels.create_tile(state, object)
      {destination, state} = Levels.update_tile_state(state, destination, %{blocking: true})

      assert {:invalid, %{}, state} == Pull.pull(puller, destination, state)
    end

    test "pulling but nothing to pull", %{state: state, puller: puller, destination: destination} do
      object           = %Tile{id: 998, row: 3, col: 2, z_index: 0, character: "X", state: "pullable: false"}
      {_object, state} = Levels.create_tile(state, object)

      assert {:ok, tile_changes, _updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"}, {2, 2} => %Tile{character: "."}} = tile_changes
      assert length(Map.keys(tile_changes)) == 2
    end

    test "successful pull of one item", %{state: state, puller: puller, destination: destination} do
      object1          = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true"}
      object2          = %Tile{id: 999, row: 3, col: 3, z_index: 1, character: "Y", state: "pullable: true"}
      {_object1, state} = Levels.create_tile(state, object1)
      {_object2, state} = Levels.create_tile(state, object2)

      assert {:ok, tile_changes, _updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"},
                {2, 2} => %Tile{character: "X"},
                {3, 2} => %Tile{character: "-"}} = tile_changes
      assert length(Map.keys(tile_changes)) == 3
    end

    test "pull a chain of items", %{state: state, puller: puller, destination: destination} do
      object1           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: true, facing: north"}
      object2           = %Tile{id: 999, row: 3, col: 3, z_index: 1, character: "Y", state: "pullable: true"}
      {_object1, state} = Levels.create_tile(state, object1)
      {_object2, state} = Levels.create_tile(state, object2)

      assert {:ok, tile_changes, _updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"},
                {2, 2} => %Tile{character: "X"},
                {3, 2} => %Tile{character: "Y"},
                {3, 3} => %Tile{character: "~"}} = tile_changes
      assert length(Map.keys(tile_changes)) == 4
    end

    test "pull a chain of items but one is blocked", %{state: state, puller: puller, destination: destination} do
      object1           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: true, facing: north"}
      object2           = %Tile{id: 999, row: 3, col: 3, z_index: 1, character: "Y", state: "pullable: true"}
      wall1             = %Tile{id: 997, row: 3, col: 2, z_index: 0, character: "#", state: "blocking: true"}
      {_object1, state} = Levels.create_tile(state, object1)
      {_object2, state} = Levels.create_tile(state, object2)
      {_wall1, state}   = Levels.create_tile(state, wall1)

      assert {:ok, tile_changes, _updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"},
                {2, 2} => %Tile{character: "X"},
                {3, 2} => %Tile{character: "Y"},
                {3, 3} => %Tile{character: "~"}} = tile_changes
      assert length(Map.keys(tile_changes)) == 4
    end

    test "pull a chain of items that form a circuit", %{state: state, puller: puller, destination: destination} do
      object1           = %Tile{id: 990, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      object2           = %Tile{id: 991, row: 3, col: 1, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      object3           = %Tile{id: 992, row: 4, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      object4           = %Tile{id: 993, row: 4, col: 1, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      {_object1, state} = Levels.create_tile(state, object1)
      {_object2, state} = Levels.create_tile(state, object2)
      {_object3, state} = Levels.create_tile(state, object3)
      {_object4, state} = Levels.create_tile(state, object4)

      assert {:ok, tile_changes, _updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"},
                {2, 2} => %Tile{character: "X"},
                {3, 2} => %Tile{character: "X"},
                {4, 2} => %Tile{},
                {4, 1} => %Tile{},
                {3, 1} => %Tile{}} = tile_changes
      assert length(Map.keys(tile_changes)) == 6
    end

    test "map_tile_id is replaced with the pullers id", %{state: state, puller: puller, destination: destination} do
      object1          = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: map_tile_id, pulling: true"}
      object2          = %Tile{id: 999, row: 4, col: 2, z_index: 1, character: "Y", state: "pullable: map_tile_id"}

      {object1, state} = Levels.create_tile(state, object1)
      {object2, state} = Levels.create_tile(state, object2)

      assert {:ok, tile_changes, updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"},
                {2, 2} => %Tile{character: "X"},
                {3, 2} => %Tile{character: "Y"},
                {4, 2} => %Tile{character: "."}} = tile_changes
      assert length(Map.keys(tile_changes)) == 4
      object1 = Levels.get_tile_by_id(updated_state, object1)
      object2 = Levels.get_tile_by_id(updated_state, object2)
      assert object1.parsed_state[:pullable] == puller.id
      assert object2.parsed_state[:pullable] == object1.id
      assert object1.parsed_state[:facing] == "north"
      assert object2.parsed_state[:facing] == "north"
    end

    test "map_tile_id for pulling is replaced with the pullees id", %{state: state, puller: puller, destination: destination} do
      object1          = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: map_tile_id"}
      object2          = %Tile{id: 999, row: 4, col: 2, z_index: 1, character: "Y", state: "pullable: map_tile_id, pulling: map_tile_id"}

      {object1, state} = Levels.create_tile(state, object1)
      {object2, state} = Levels.create_tile(state, object2)

      assert {:ok, tile_changes, updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %Tile{character: "@"},
                {2, 2} => %Tile{character: "X"},
                {3, 2} => %Tile{character: "Y"},
                {4, 2} => %Tile{character: "."}} = tile_changes
      assert length(Map.keys(tile_changes)) == 4
      object1 = Levels.get_tile_by_id(updated_state, object1)
      object2 = Levels.get_tile_by_id(updated_state, object2)
      assert object1.parsed_state[:pullable] == true
      assert object2.parsed_state[:pullable] == object1.id
      assert object1.parsed_state[:facing] == "north"
      assert object2.parsed_state[:facing] == "north"
      assert object1.parsed_state[:pulling] == object2.id
      assert object2.parsed_state[:pulling] == false
    end

    test "cant pull bad inputs" do
      assert {:invalid, %{}, "doesnt match the params"} == Pull.pull("anything", "that", "doesnt match the params")
    end
  end

  describe "would_not_pull/2" do
    test "would not pull", %{state: state} do
      object1          = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pulling: 1000"}
      object2          = %Tile{id: 999, row: 4, col: 2, z_index: 1, character: "Y", state: "pullable: true"}

      {object1, state} = Levels.create_tile(state, object1)
      {object2, _state} = Levels.create_tile(state, object2)

      assert Pull.would_not_pull(object1, object2)
    end

    test "would pull", %{state: state} do
      object1          = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pulling: 999"}
      object2          = %Tile{id: 999, row: 4, col: 2, z_index: 1, character: "Y", state: "pullable: true"}

      {object1, state} = Levels.create_tile(state, object1)
      {object2, _state} = Levels.create_tile(state, object2)

      refute Pull.would_not_pull(object1, object2)
    end
  end

  describe "can_pull/3" do
    test "cannot pull", %{state: state, puller: puller, destination: destination} do
      object           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X"}
      {object, _state} = Levels.create_tile(state, object)
      refute Pull.can_pull(puller, object, destination)
    end

    test "cannot pull a tile that is in the direction puller is moving to", %{state: state, puller: puller, destination: destination} do
      object           = %Tile{id: 998, row: 1, col: 2, z_index: 1, character: "X", state: "pullable: true"}
      {object, _state} = Levels.create_tile(state, object)
      refute Pull.can_pull(puller, object, destination)
    end

    test "can pull", %{state: state, puller: puller, destination: destination} do
      object           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true"}
      {object, _state} = Levels.create_tile(state, object)
      assert Pull.can_pull(puller, object, destination)
    end

    test "pullable but only linearly", %{state: state, puller: puller, destination: destination} do
      object1           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: linear"}
      object2           = %Tile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: linear"}
      {object1, state} = Levels.create_tile(state, object1)
      {object2, _state} = Levels.create_tile(state, object2)

      assert Pull.can_pull(puller, object1, destination) # moving north, and puller is moving north
      refute Pull.can_pull(puller, object2, destination) # would have to move west, while puller is going north
    end

    test "pullable but only in a specified direction", %{state: state, puller: puller, destination: destination} do
      object1           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: s"}
      object2           = %Tile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: ew"}
      {object1, state} = Levels.create_tile(state, object1)
      {object2, _state} = Levels.create_tile(state, object2)

      refute Pull.can_pull(puller, object1, destination) # not pullable north, and puller is moving north
      assert Pull.can_pull(puller, object2, destination) # pullable east and west, while puller is going north pulling the tile west
    end

    test "pullable but only by a specific tile id", %{state: state, puller: puller, destination: destination} do
      # this could be generic, then set automatically at runtime
      object1           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: #{puller.id}"}
      object2           = %Tile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: 12345"}
      object3           = %Tile{id: 992, row: 2, col: 1, z_index: 1, character: "X", state: "pullable: map_tile_id"}
      {object1, state} = Levels.create_tile(state, object1)
      {object2, state} = Levels.create_tile(state, object2)
      {object3, _state} = Levels.create_tile(state, object3)

      assert Pull.can_pull(puller, object1, destination)
      refute Pull.can_pull(puller, object2, destination)
      assert Pull.can_pull(puller, object3, destination)
    end

    test "cant pull bad inputs" do
      refute Pull.can_pull("anything", "that", "doesnt match the params")
    end
  end

  describe "can_pull/4" do
    test "takes into account tiles already being pulled", %{state: state, puller: puller, destination: destination} do
      object1           = %Tile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      object2           = %Tile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      {object1, state} = Levels.create_tile(state, object1)
      {object2, _state} = Levels.create_tile(state, object2)

      assert Pull.can_pull(puller, object1, destination, [{object2, puller}])
      refute Pull.can_pull(puller, object1, destination, [{object1, object2}, {object2, puller}])
    end
  end
end


defmodule DungeonCrawl.Action.PullTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Pull
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.Instances

  setup _config do
    instance = insert_stubbed_dungeon_instance(%{},
      [%MapTile{character: ".", row: 1, col: 2, z_index: 0},
       %MapTile{character: ".", row: 2, col: 2, z_index: 0},
       %MapTile{character: "-", row: 3, col: 2, z_index: 0},
       %MapTile{character: "~", row: 3, col: 3, z_index: 0},
       %MapTile{character: "@", row: 2, col: 2, z_index: 1}])

    # Quik and dirty state init
    state = Repo.preload(instance, :dungeon_map_tiles).dungeon_map_tiles
            |> Enum.reduce(%Instances{}, fn(dmt, state) -> 
                 {_, state} = Instances.create_map_tile(state, dmt)
                 state
               end)

    destination = Instances.get_map_tile(state, %{row: 1, col: 2})
    puller = Instances.get_map_tile(state, %{row: 2, col: 2})
    %{state: state, puller: puller, destination: destination}
  end

  describe "pull/3" do
    test "pulling but movement is blocked", %{state: state, puller: puller, destination: destination} do
      object           = %MapTile{id: 998, row: 3, col: 2, z_index: 0, character: "X", state: "pullable: true"}
      {_object, state} = Instances.create_map_tile(state, object)
      {destination, state} = Instances.update_map_tile_state(state, destination, %{blocking: true})

      assert {:invalid} == Pull.pull(puller, destination, state)
    end

    test "pulling but nothing to pull", %{state: state, puller: puller, destination: destination} do
      object           = %MapTile{id: 998, row: 3, col: 2, z_index: 0, character: "X", state: "pullable: false"}
      {_object, state} = Instances.create_map_tile(state, object)

      assert {:ok, tile_changes, updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %MapTile{character: "@"}, {2, 2} => %MapTile{character: "."}} = tile_changes
      assert length(Map.keys(tile_changes)) == 2
    end

    test "successful pull of one item", %{state: state, puller: puller, destination: destination} do
      object1          = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true"}
      object2          = %MapTile{id: 999, row: 3, col: 3, z_index: 1, character: "Y", state: "pullable: true"}
      {_object1, state} = Instances.create_map_tile(state, object1)
      {_object2, state} = Instances.create_map_tile(state, object2)

      assert {:ok, tile_changes, updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %MapTile{character: "@"},
                {2, 2} => %MapTile{character: "X"},
                {3, 2} => %MapTile{character: "-"}} = tile_changes
      assert length(Map.keys(tile_changes)) == 3
    end

    test "pull a chain of items", %{state: state, puller: puller, destination: destination} do
      object1           = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true, pulling: true"}
      object2           = %MapTile{id: 999, row: 3, col: 3, z_index: 1, character: "Y", state: "pullable: true"}
      {_object1, state} = Instances.create_map_tile(state, object1)
      {_object2, state} = Instances.create_map_tile(state, object2)

      assert {:ok, tile_changes, updated_state} = Pull.pull(puller, destination, state)
      assert %{ {1, 2} => %MapTile{character: "@"},
                {2, 2} => %MapTile{character: "X"},
                {3, 2} => %MapTile{character: "Y"},
                {3, 3} => %MapTile{character: "~"}} = tile_changes
      assert length(Map.keys(tile_changes)) == 4
    end

    test "cant pull bad inputs" do
      assert {:invalid} == Pull.pull("anything", "that", "doesnt match the params")
    end
  end

  describe "can_pull/3" do
    test "cannot pull", %{state: state, puller: puller, destination: destination} do
      object           = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X"}
      {object, _state} = Instances.create_map_tile(state, object)
      refute Pull.can_pull(puller, object, destination)
    end

    test "cannot pull a tile that is in the direction puller is moving to", %{state: state, puller: puller, destination: destination} do
      object           = %MapTile{id: 998, row: 1, col: 2, z_index: 1, character: "X", state: "pullable: true"}
      {object, _state} = Instances.create_map_tile(state, object)
      refute Pull.can_pull(puller, object, destination)
    end

    test "can pull", %{state: state, puller: puller, destination: destination} do
      object           = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: true"}
      {object, _state} = Instances.create_map_tile(state, object)
      assert Pull.can_pull(puller, object, destination)
    end

    test "pullable but only linearly", %{state: state, puller: puller, destination: destination} do
      object1           = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: linear"}
      object2           = %MapTile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: linear"}
      {object1, state} = Instances.create_map_tile(state, object1)
      {object2, _state} = Instances.create_map_tile(state, object2)

      assert Pull.can_pull(puller, object1, destination) # moving north, and puller is moving north
      refute Pull.can_pull(puller, object2, destination) # would have to move west, while puller is going north
    end

    test "pullable but only in a specified direction", %{state: state, puller: puller, destination: destination} do
      object1           = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: s"}
      object2           = %MapTile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: ew"}
      {object1, state} = Instances.create_map_tile(state, object1)
      {object2, _state} = Instances.create_map_tile(state, object2)

      refute Pull.can_pull(puller, object1, destination) # not pullable north, and puller is moving north
      assert Pull.can_pull(puller, object2, destination) # pullable east and west, while puller is going north pulling the tile west
    end

    test "pullable but only by a specific map tile id", %{state: state, puller: puller, destination: destination} do
      # this could be generic, then set automatically at runtime
      object1           = %MapTile{id: 998, row: 3, col: 2, z_index: 1, character: "X", state: "pullable: #{puller.id}"}
      object2           = %MapTile{id: 999, row: 2, col: 3, z_index: 1, character: "X", state: "pullable: 12345"}
      {object1, state} = Instances.create_map_tile(state, object1)
      {object2, _state} = Instances.create_map_tile(state, object2)

      assert Pull.can_pull(puller, object1, destination)
      refute Pull.can_pull(puller, object2, destination)
    end

    test "cant pull bad inputs" do
      refute Pull.can_pull("anything", "that", "doesnt match the params")
    end
  end
end


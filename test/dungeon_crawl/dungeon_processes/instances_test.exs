defmodule DungeonCrawl.DungeonProcesses.InstancesTest do
  use DungeonCrawl.DataCase

  import ExUnit.CaptureLog

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.MapTile

  setup do
    map_tile =        %MapTile{id: 999, row: 1, col: 2, z_index: 0, character: "B", state: "", script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#DIE"}
    map_tile_south_1  = %MapTile{id: 997, row: 1, col: 3, z_index: 1, character: "S", state: "", script: ""}
    map_tile_south_2  = %MapTile{id: 998, row: 1, col: 3, z_index: 0, character: "X", state: "", script: ""}

    {_, state} = Instances.create_map_tile(%Instances{}, map_tile)
    {_, state} = Instances.create_map_tile(state, map_tile_south_1)
    {_, state} = Instances.create_map_tile(state, map_tile_south_2)

    %{state: state}
  end

  test "the state looks right", %{state: state} do
    assert %Instances{
      program_contexts: %{999 => %{
                  event_sender: nil,
                  object: %{ id: 999, character: "B", # ...
                  },
                  program: %DungeonCrawl.Scripting.Program{
                    broadcasts: [],
                    instructions: %{
                      1 => [:halt, [""]],
                      2 => [:noop, "TOUCH"],
                      3 => [:text, ["Hey"]],
                      4 => [:halt, [""]],
                      5 => [:noop, "TERMINATE"],
                      6 => [:die, [""]]
                    },
                    labels: %{
                      "TERMINATE" => [[5, true]],
                      "TOUCH" => [[2, true]]
                    },
                    locked: false,
                    pc: 1,
                    responses: [],
                    status: :alive,
                    wait_cycles: 0
                  }
                }
             },
      map_by_ids: %{999 => %{id: 999}, # More here, but this is good enough for a smoke test
                    997 => %{id: 997},
                    998 => %{id: 998}},
      map_by_coords: %{ {1, 2} => %{0 => 999},
                        {1, 3} => %{1 => 997, 0 => 998} }
    } = state
  end

  test "get_map_tile/1 gets the top map tile at the given coordinates", %{state: state} do
    assert %{id: 999} = Instances.get_map_tile(state, %{row: 1, col: 2})
  end

  test "get_map_tile/2 gets the top map tile in the given direction", %{state: state} do
    assert %{id: 997} = Instances.get_map_tile(state, %{row: 1, col: 2}, "east")
  end

  test "get_map_tiles/2 gets the map tiles in the given direction", %{state: state} do
    assert [map_tile_1, map_tile_2] = Instances.get_map_tiles(state, %{row: 1, col: 2}, "east")
    assert %{id: 997} = map_tile_1
    assert %{id: 998} = map_tile_2
  end

  test "get_map_tiles/2 gets empty array in the given direction", %{state: state} do
    assert [] == Instances.get_map_tiles(state, %{row: 1, col: 2}, "north")
  end

  test "get_map_tile_by_id/1 gets the map tile for the id", %{state: state} do
    assert %{id: 999} = Instances.get_map_tile_by_id(state, %{id: 999})
  end

  test "responds_to_event?/3", %{state: state} do
    assert Instances.responds_to_event?(state, %{id: 999}, "TOUCH")
    refute Instances.responds_to_event?(state, %{id: 999}, "SNIFF")
    refute Instances.responds_to_event?(state, %{id: 222}, "ANYTHING")
  end

  test "send_event", %{state: state} do
    player_location = %Location{id: 555}

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    %Instances{ program_contexts: %{999 => %{program: program} },
                map_by_ids: _,
                map_by_coords: _ } = state

    # noop if it tile doesnt have a program
    updated_state = Instances.send_event(state, %{id: 111}, "TOUCH", player_location)
    %Instances{ program_contexts: %{999 => %{program: ^program} },
                map_by_ids: _,
                map_by_coords: _ } = updated_state

    # it does something
    updated_state_2 = Instances.send_event(updated_state, %{id: 999}, "TOUCH", player_location)
    %Instances{ program_contexts: %{999 => %{program: updated_program} },
                map_by_ids: _,
                map_by_coords: _ } = updated_state_2
    refute program == updated_program
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "Hey"}}

    # prunes the program if died during the run of the label
    updated_state_3 = Instances.send_event(updated_state_2, %{id: 999}, "TERMINATE", player_location)
    %Instances{ program_contexts: %{} ,
                map_by_ids: _,
                map_by_coords: _ } = updated_state_3
  end

  test "create_map_tile/1 creates a map tile" do
    new_map_tile = %{id: 1, row: 4, col: 4, z_index: 0, character: "M", state: "", script: ""}

    {new_map_tile, state} = Instances.create_map_tile(%Instances{}, new_map_tile)

    assert %{id: 1, character: "M"} = new_map_tile
    assert %Instances{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_map_tile, :parsed_state, %{})},
      map_by_coords: %{ {4, 4} => %{0 => 1} }
    } == state

    # returns the existing tile if it already exists by id
    assert {^new_map_tile, ^state} = Instances.create_map_tile(state, Map.put(new_map_tile, :character, "O"))
    assert %{id: 1, character: "M"} = new_map_tile

    # Does not load a corrupt script (edge case - corrupt script shouldnt even get into the DB, and logs a warning
    map_tile_bad_script = %MapTile{row: 1, col: 4, id: 123, script: "#NOT_A_REAL_COMMAND"}
    assert capture_log(fn ->
             assert {map_tile, updated_state} = Instances.create_map_tile(state, map_tile_bad_script)
             assert %Instances{ program_contexts: %{},
                                map_by_ids: %{1 => Map.put(new_map_tile, :parsed_state, %{}),
                                              123 => Map.put(map_tile_bad_script, :parsed_state, %{})},
                                map_by_coords: %{{1, 4} => %{0 => 123}, {4, 4} => %{0 => 1}} } == updated_state
           end) =~ ~r/Possible corrupt script for map tile instance:/
  end

  test "update_map_tile/2 updates the map tile", %{state: state} do
    map_tile = Instances.get_map_tile(state, %{id: 999, row: 1, col: 2})
    new_attributes = %{id: 333, row: 2, col: 2, character: "M"}

    assert {updated_tile, updated_state} = Instances.update_map_tile(state, map_tile, new_attributes)
    assert Map.merge(map_tile, %{row: 2, col: 2, character: "M"}) == updated_tile
    changeset = MapTile.changeset(%MapTile{},%{character: "M", row: 2})
    assert %{dirty_ids: %{999 => changeset}} = updated_state
  end

  test "update_tile/3", %{state: state} do
    map_tile_id = 999
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{id: 11111, character: "X", row: 1, col: 1})
    assert %{id: ^map_tile_id, character: "X", row: 1, col: 1} = state.map_by_ids[map_tile_id]
    changeset = MapTile.changeset(%MapTile{},%{character: "X", col: 1})
    assert %{dirty_ids: %{999 => changeset}} = state

    # Move to an empty space
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{row: 2, col: 3})
    assert %{id: ^map_tile_id, character: "X", row: 2, col: 3} = state.map_by_ids[map_tile_id]
    changeset = MapTile.changeset(%MapTile{},%{character: "X", row: 2, col: 3})
    assert %{dirty_ids: %{999 => changeset}} = state

    # Move ontop of another tile
    another_map_tile = %MapTile{id: -3, character: "O", row: 5, col: 6, z_index: 0}
    {another_map_tile, state} = Instances.create_map_tile(state, another_map_tile)

    # Won't move to the same z_index
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{row: 5, col: 6})
    assert %MapTile{id: ^map_tile_id, character: "X", row: 2, col: 3, z_index: 0} = state.map_by_ids[map_tile_id]
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{row: 5, col: 6, z_index: 1})
    assert %MapTile{id: ^map_tile_id, character: "X", row: 5, col: 6, z_index: 1} = state.map_by_ids[map_tile_id]
    assert %MapTile{id: -3, character: "O", row: 5, col: 6, z_index: 0} = state.map_by_ids[-3]

    # Move the new tile
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: -3}, %{character: "M"})
    changeset_999   = MapTile.changeset(%MapTile{},%{character: "X", row: 5, col: 6, z_index: 1})
    changeset_neg_3 = MapTile.changeset(%MapTile{},%{character: "M"})
    assert %{dirty_ids: %{999 => changeset}} = state
    assert %{dirty_ids: %{999 => changeset_999, -3 => changeset_neg_3}} = state
  end

  test "delete_map_tile/1 deletes the map tile", %{state: state} do
    map_tile_id = 999
    map_tile = state.map_by_ids[map_tile_id]

    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord } = state
    assert programs[map_tile.id]
    assert by_id[map_tile.id]
    assert %{ {1, 2} => %{ 0 => ^map_tile_id} } = by_coord

    assert {deleted_tile, state} = Instances.delete_map_tile(state, map_tile)
    refute state.map_by_ids[map_tile_id]
    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord,
                dirty_ids: %{^map_tile_id => :deleted} } = state
    refute programs[map_tile_id]
    refute by_id[map_tile_id]
    assert %{ {1, 2} => %{} } = by_coord
  end
end

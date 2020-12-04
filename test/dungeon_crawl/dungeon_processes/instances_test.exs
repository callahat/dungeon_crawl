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
                  object_id: 999,
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
                      "terminate" => [[5, true]],
                      "touch" => [[2, true]]
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

  test "get_map_tile/2 gets the top map tile at the given coordinates", %{state: state} do
    assert %{id: 999} = Instances.get_map_tile(state, %{row: 1, col: 2})
  end

  test "get_map_tile/3 gets the top map tile in the given direction", %{state: state} do
    assert %{id: 997} = Instances.get_map_tile(state, %{row: 1, col: 2}, "east")
  end

  test "get_map_tiles/3 gets the map tiles in the given direction", %{state: state} do
    assert [map_tile_1, map_tile_2] = Instances.get_map_tiles(state, %{row: 1, col: 2}, "east")
    assert %{id: 997} = map_tile_1
    assert %{id: 998} = map_tile_2
  end

  test "get_map_tiles/3 gets empty array in the given direction", %{state: state} do
    assert [] == Instances.get_map_tiles(state, %{row: 1, col: 2}, "north")
  end

  test "get_map_tile_by_id/2 gets the map tile for the id", %{state: state} do
    assert %{id: 999} = Instances.get_map_tile_by_id(state, %{id: 999})
  end

  test "get_player_location/2", %{state: state} do
    player_tile = %{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "", script: ""}
    location = %Location{user_id_hash: "dubs", map_tile_instance_id: 123}
    {player_tile, state} = Instances.create_player_map_tile(state, player_tile, location)

    # using a map tile id
    assert Instances.get_player_location(state, %{id: player_tile.id}) == location
    refute Instances.get_player_location(state, %{id: 99999})

    # using user_id_hash
    assert Instances.get_player_location(state, "dubs") == location
    refute Instances.get_player_location(state, "notrealhash")
  end

  test "responds_to_event?/3", %{state: state} do
    assert Instances.responds_to_event?(state, %{id: 999}, "TOUCH")
    refute Instances.responds_to_event?(state, %{id: 999}, "SNIFF")
    refute Instances.responds_to_event?(state, %{id: 222}, "ANYTHING")
  end

  test "send_event/4", %{state: state} do
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

  test "add_message_action/3" do
    state = Instances.set_message_actions(%Instances{}, 123, ["maybe", "ok"])
            |> Instances.set_message_actions(777, ["negative"])
    assert state.message_actions == %{123 => ["maybe", "ok"], 777 => ["negative"]}
  end

  test "remove_message_actions/2" do
    state = %Instances{ message_actions: %{123 => ["maybe", "ok"], 777 => ["negative"]} }
    updated_state = Instances.remove_message_actions(state, 123)
    refute Map.has_key?(updated_state, 123)
    assert updated_state.message_actions == %{ 777 => ["negative"] }
  end

  test "valid_message_action?/3" do
    state = %Instances{ message_actions: %{123 => ["maybe", "ok"], 777 => ["negative"]} }
    assert Instances.valid_message_action?(state, 123, "maybe")
    assert Instances.valid_message_action?(state, 777, "negative")
    refute Instances.valid_message_action?(state, 777, "ok")
    refute Instances.valid_message_action?(state, 999234, "ok")
  end

  test "create_player_map_tile/3 creates a player map tile and regsiters it" do
    new_map_tile = %{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "", script: ""}
    location = %Location{user_id_hash: "dubs", map_tile_instance_id: 123}

    {new_map_tile, state} = Instances.create_player_map_tile(%Instances{}, new_map_tile, location)

    assert %{id: 1, character: "@"} = new_map_tile
    assert %Instances{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_map_tile, :parsed_state, %{})},
      map_by_coords: %{ {4, 4} => %{1 => 1} },
      player_locations: %{new_map_tile.id => location},
      rerender_coords: %{%{col: 4, row: 4} => true}
    } == state

    # returns the existing tile if it already exists by id, but links player location
    assert {^new_map_tile, state} = Instances.create_player_map_tile(state, Map.put(new_map_tile, :character, "O"), location)
    assert %{id: 1, character: "@"} = new_map_tile
    assert %Instances{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_map_tile, :parsed_state, %{})},
      map_by_coords: %{ {4, 4} => %{1 => 1} },
      player_locations: %{new_map_tile.id => location},
      rerender_coords: %{%{col: 4, row: 4} => true}
    } == state
  end

  test "create_map_tile/2 creates a map tile" do
    new_map_tile = %{id: 1, row: 4, col: 4, z_index: 0, character: "M", state: "", script: ""}

    {new_map_tile, state} = Instances.create_map_tile(%Instances{}, new_map_tile)

    assert %{id: 1, character: "M"} = new_map_tile
    assert %Instances{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_map_tile, :parsed_state, %{})},
      map_by_coords: %{ {4, 4} => %{0 => 1} },
      new_pids: [],
      rerender_coords: %{%{col: 4, row: 4} => true}
    } == state

    # assigns a temporary id when it does not have one, which indicates this tile has not been persisted to the database yet
    assert {new_map_tile_1, updated_state} = Instances.create_map_tile(state, Map.merge(new_map_tile, %{id: nil, row: 5}))
    assert is_binary(new_map_tile_1.id)
    assert String.starts_with?(new_map_tile_1.id, "new_")
    assert updated_state.new_ids == %{new_map_tile_1.id => 0}

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
                                map_by_coords: %{{1, 4} => %{0 => 123}, {4, 4} => %{0 => 1}},
                                rerender_coords: %{%{col: 4, row: 1} => true, %{col: 4, row: 4} => true} } == updated_state
           end) =~ ~r/Possible corrupt script for map tile instance:/

    # If there's a program that starts, adds the map_tile_id to new_pids, so Instances._cycle_program
    # can know to save it and add it back to the map of updated program_contexts.
    map_tile_good_script = %MapTile{character: "U", row: 1, col: 4, id: 123, script: "#SHOOT north"}
    {new_map_tile, state} = Instances.create_map_tile(%Instances{}, map_tile_good_script)
    assert %{id: 123, character: "U"} = new_map_tile
    assert %Instances{
      program_contexts: %{123 => _},
      map_by_ids: %{123 => ^new_map_tile},
      map_by_coords: %{ {1, 4} => %{0 => 123} },
      new_pids: [ 123 ],
      rerender_coords: %{%{col: 4, row: 1} => true}
    } = state
  end

  test "set_map_tile_id/3" do
    map_tile = %{id: 1000, row: 3, col: 4, z_index: 0, character: "M", state: "", script: "#END"}
    {_map_tile, state} = Instances.create_map_tile(%Instances{}, map_tile)
    program_contexts = %{ 1000 => %{ program: %{state.program_contexts[1000].program |
                                                 messages: [{"touch", %{map_tile_id: "new_0"}},
                                                            {"touch", nil},
                                                            {"touch", Map.merge(%Location{}, %{parsed_state: {}} )}]},
                                     event_sender: %{map_tile_id: "new_0"} }}
    state = %{ state | program_contexts: program_contexts }

    new_map_tile = %{id: nil, row: 4, col: 4, z_index: 0, character: "M", state: "blocking: true", script: "#END\n:touch\nHI"}
    {new_map_tile, state} = Instances.create_map_tile(state, new_map_tile)
    assert new_map_tile.id == "new_0"

    # noop if the new id is not and int or the old id is not a binary
    assert ^state = Instances.set_map_tile_id(state, %{id: "new_0"}, "new_0")
    assert ^state = Instances.set_map_tile_id(state, %{id: 1}, 2)

    # stuff gets updated
    assert updated_state = Instances.set_map_tile_id(state, Map.put(new_map_tile, :id, 1), new_map_tile.id)
    assert Map.delete(updated_state.map_by_ids[1], :id) == Map.delete(state.map_by_ids[new_map_tile.id], :id)
    refute updated_state.map_by_ids[1].id == new_map_tile.id
    assert is_integer(updated_state.map_by_ids[1].id)
    assert updated_state.map_by_coords[{4,4}] == %{0 => 1}
    assert %{1 => %{object_id: 1}} = updated_state.program_contexts
    refute updated_state.program_contexts[new_map_tile.id]

    assert updated_state.program_contexts[1000].program.messages == [{"touch", %{map_tile_id: 1}},
                                                                     {"touch", nil},
                                                                     {"touch", Map.merge(%Location{}, %{parsed_state: {}})}]
    assert updated_state.program_contexts[1000].event_sender == %{map_tile_id: 1}
  end

  test "set_map_tile_id/3 when new tile has no script" do
    new_map_tile = %{id: nil, row: 4, col: 4, z_index: 0, character: "M", state: "blocking: true", script: ""}
    {new_map_tile, state} = Instances.create_map_tile(%Instances{}, new_map_tile)
    assert new_map_tile.id == "new_0"

    # noop if the new id is not and int or the old id is not a binary
    assert ^state = Instances.set_map_tile_id(state, %{id: "new_0"}, "new_0")
    assert ^state = Instances.set_map_tile_id(state, %{id: 1}, 2)

    # stuff gets updated
    assert updated_state = Instances.set_map_tile_id(state, Map.put(new_map_tile, :id, 1), new_map_tile.id)
    assert Map.delete(updated_state.map_by_ids[1], :id) == Map.delete(state.map_by_ids[new_map_tile.id], :id)
    refute updated_state.map_by_ids[1].id == new_map_tile.id
    assert is_integer(updated_state.map_by_ids[1].id)
    assert updated_state.map_by_coords[{4,4}] == %{0 => 1}
    assert %{} == updated_state.program_contexts
  end

  test "update_map_tile_state/3", %{state: state} do
    map_tile = Instances.get_map_tile(state, %{id: 999, row: 1, col: 2})
    assert {map_tile, state} = Instances.update_map_tile_state(state, map_tile, %{hamburders: 4})
    assert map_tile.parsed_state[:hamburders] == 4
    assert map_tile.state == "hamburders: 4"

    assert {map_tile, state} = Instances.update_map_tile_state(state, map_tile, %{coffee: 2})
    assert map_tile.parsed_state[:hamburders] == 4
    assert map_tile.parsed_state[:coffee] == 2
    assert map_tile.state == "coffee: 2, hamburders: 4"
  end

  test "update_map_tile/3 updates the map tile", %{state: state} do
    map_tile = Instances.get_map_tile(state, %{id: 999, row: 1, col: 2})
    new_attributes = %{id: 333, row: 2, col: 2, character: "M"}

    assert {updated_tile, updated_state} = Instances.update_map_tile(state, map_tile, new_attributes)
    assert Map.merge(map_tile, %{row: 2, col: 2, character: "M"}) == updated_tile
    assert %{dirty_ids: %{999 => changeset}} = updated_state
    assert changeset.changes == MapTile.changeset(map_tile,%{character: "M", row: 2}).changes
  end

  test "update_tile/3", %{state: state} do
    map_tile_id = 999
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{id: 11111, character: "X", row: 1, col: 1})
    assert %{id: ^map_tile_id, character: "X", row: 1, col: 1} = state.map_by_ids[map_tile_id]
    assert %{dirty_ids: %{999 => changeset}} = state
    assert changeset.changes == MapTile.changeset(%MapTile{},%{character: "X", col: 1}).changes

    # Move to an empty space
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{row: 2, col: 3})
    assert %{id: ^map_tile_id, character: "X", row: 2, col: 3} = state.map_by_ids[map_tile_id]
    assert %{dirty_ids: %{999 => changeset}} = state
    assert changeset.changes == MapTile.changeset(%MapTile{},%{character: "X", row: 2, col: 3}).changes

    # Move ontop of another tile
    another_map_tile = %MapTile{id: -3, character: "O", row: 5, col: 6, z_index: 0}
    {_another_map_tile, state} = Instances.create_map_tile(state, another_map_tile)

    # Won't move to the same z_index
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{row: 5, col: 6})
    assert %MapTile{id: ^map_tile_id, character: "X", row: 2, col: 3, z_index: 0} = state.map_by_ids[map_tile_id]
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: map_tile_id}, %{row: 5, col: 6, z_index: 1})
    assert %MapTile{id: ^map_tile_id, character: "X", row: 5, col: 6, z_index: 1} = state.map_by_ids[map_tile_id]
    assert %MapTile{id: -3, character: "O", row: 5, col: 6, z_index: 0} = state.map_by_ids[-3]

    # Move the new tile
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: -3}, %{character: "M"})
    assert %{dirty_ids: %{999 => changeset_999, -3 => changeset_neg_3}} = state
    assert changeset_999.changes == MapTile.changeset(%MapTile{},%{character: "X", row: 5, col: 6, z_index: 1}).changes
    assert changeset_neg_3.changes == MapTile.changeset(%MapTile{},%{character: "M"}).changes

    # Adds a program
    refute state.program_contexts[-3]
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: -3}, %{script: "#END\n:TOUCH\n?s"})
    assert %{-3 => %{program: program, object_id: -3}} = state.program_contexts
    assert %{map_by_ids: %{-3 => %MapTile{script: "#END\n:TOUCH\n?s"}}} = state
    assert %DungeonCrawl.Scripting.Program{
             broadcasts: [],
             instructions: %{
               1 => [:halt, [""]],
               2 => [:noop, "TOUCH"],
               3 => [:compound_move, [{"south", false}]]
             },
             labels: %{
               "touch" => [[2, true]]
             },
             locked: false,
             pc: 1,
             responses: [],
             status: :wait,
             wait_cycles: 0
           } = program

    # Adds a different program to something with one already
    assert state.program_contexts[999]
    assert state.program_contexts[999].program.status == :alive
    assert {updated_tile, state} = Instances.update_map_tile(state, %{id: 999}, %{script: "?n"})
    assert %{999 => %{program: program, object_id: 999}} = state.program_contexts
    assert %{map_by_ids: %{999 => %MapTile{script: "?n"}}} = state
    assert %DungeonCrawl.Scripting.Program{
             broadcasts: [],
             instructions: %{
               1 => [:compound_move, [{"north", false}]]
             },
             labels: %{},
             locked: false,
             pc: 1,
             responses: [],
             status: :wait,
             wait_cycles: 0
           } = program
  end

  test "delete_player_map_tile/2 deletes the map tile and unregisters player location", %{state: state} do
    map_tile_id = 999
    map_tile = state.map_by_ids[map_tile_id]

    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord } = state
    state = %{ state | player_locations: %{ map_tile_id => %Location{} }}
    assert programs[map_tile.id]
    assert by_id[map_tile.id]
    assert %{ {1, 2} => %{ 0 => ^map_tile_id} } = by_coord

    assert {deleted_tile, state} = Instances.delete_map_tile(state, map_tile)
    refute state.map_by_ids[map_tile_id]
    refute state.player_locations[map_tile_id]
    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord,
                dirty_ids: %{^map_tile_id => :deleted},
                player_locations: player_locations } = state
    refute programs[map_tile_id]
    refute by_id[map_tile_id]
    assert %{ {1, 2} => %{} } = by_coord
    assert %{} == player_locations
  end

  test "delete_player_map_tile/3 removes the map tile and unregisters player location, but does not mark for deletion", %{state: state} do
    map_tile_id = 999
    map_tile = state.map_by_ids[map_tile_id]

    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord } = state
    state = %{ state | player_locations: %{ map_tile_id => %Location{} }}
    assert programs[map_tile.id]
    assert by_id[map_tile.id]
    assert %{ {1, 2} => %{ 0 => ^map_tile_id} } = by_coord

    assert {deleted_tile, state} = Instances.delete_map_tile(state, map_tile, false) # false parameter
    refute state.map_by_ids[map_tile_id]
    refute state.player_locations[map_tile_id]
    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord,
                dirty_ids: %{}, # the only other thing different from the above test
                player_locations: player_locations } = state
    refute programs[map_tile_id]
    refute by_id[map_tile_id]
    assert %{ {1, 2} => %{} } = by_coord
    assert %{} == player_locations
  end

  test "delete_map_tile/2 deletes the map tile", %{state: state} do
    map_tile_id = 999
    map_tile = state.map_by_ids[map_tile_id]
    state = %{ state | passage_exits: [{map_tile_id, "tunnel_a"}] }

    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord,
                passage_exits: passage_exits } = state
    assert programs[map_tile.id]
    assert by_id[map_tile.id]
    assert %{ {1, 2} => %{ 0 => ^map_tile_id} } = by_coord
    assert passage_exits == [{map_tile_id, "tunnel_a"}]

    assert {deleted_tile, state} = Instances.delete_map_tile(state, map_tile)
    refute state.map_by_ids[map_tile_id]
    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord,
                dirty_ids: %{^map_tile_id => :deleted},
                passage_exits: passage_exits } = state
    refute programs[map_tile_id]
    refute by_id[map_tile_id]
    assert passage_exits == []
    assert %{ {1, 2} => %{} } = by_coord
  end

  test "direction_of_map_tile/3" do
    map_tile_nw = %MapTile{id: 990, row: 2, col: 2, z_index: 0, character: "."}
    map_tile_n  = %MapTile{id: 991, row: 2, col: 3, z_index: 0, character: "#", state: "blocking: true"}
    map_tile_ne = %MapTile{id: 992, row: 2, col: 4, z_index: 0, character: "."}
    map_tile_w  = %MapTile{id: 993, row: 3, col: 2, z_index: 0, character: "#", state: "blocking: true"}
    map_tile_me = %MapTile{id: 994, row: 3, col: 3, z_index: 0, character: "@"}
    map_tile_e  = %MapTile{id: 995, row: 3, col: 4, z_index: 0, character: "."}
    map_tile_sw = %MapTile{id: 996, row: 4, col: 2, z_index: 0, character: "."}
    map_tile_s  = %MapTile{id: 997, row: 4, col: 3, z_index: 0, character: "."}
    map_tile_se = %MapTile{id: 998, row: 4, col: 4, z_index: 0, character: "."}

    {_, state} = Instances.create_map_tile(%Instances{}, map_tile_nw)
    {_, state} = Instances.create_map_tile(state, map_tile_n)
    {_, state} = Instances.create_map_tile(state, map_tile_ne)
    {_, state} = Instances.create_map_tile(state, map_tile_w)
    {_, state} = Instances.create_map_tile(state, map_tile_me)
    {_, state} = Instances.create_map_tile(state, map_tile_e)
    {_, state} = Instances.create_map_tile(state, map_tile_sw)
    {_, state} = Instances.create_map_tile(state, map_tile_s)
    {_, state} = Instances.create_map_tile(state, map_tile_se)

    # If target is at same coords as object, idle
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_me) == "idle"
    # Target inline but is blocked, still returns the direction
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_n) == "north"
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_w) == "west"
    # Target inline and unblocked
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_s) == "south"
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_e) == "east"
    # Target is in a diagonal direction, preference given to the non blocked
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_ne) == "east"
    assert Instances.direction_of_map_tile(state, map_tile_me, map_tile_sw) == "south"
    # Target is in a diagonal direction, non blocked, one is picked
    assert Enum.member?(["south", "east"], Instances.direction_of_map_tile(state, map_tile_me, map_tile_se))
    # Target is in a diagonal direction, both blocked, one is picked
    assert Enum.member?(["north", "west"], Instances.direction_of_map_tile(state, map_tile_me, map_tile_nw))
  end

  test "is_player_tile?/2" do
    player_tile = %{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "", script: ""}
    other_map_tile = %MapTile{id: 998, row: 4, col: 4, z_index: 0, character: "."}
    location = %Location{user_id_hash: "dubs", map_tile_instance_id: 123}

    {player_tile, state} = Instances.create_player_map_tile(%Instances{}, player_tile, location)
    {other_map_tile, state} = Instances.create_map_tile(state, other_map_tile)

    assert Instances.is_player_tile?(state, player_tile)
    refute Instances.is_player_tile?(state, other_map_tile)
    refute Instances.is_player_tile?(state, %{id: 236346565456})
  end

  test "set_state_value/3" do
    state = Instances.set_state_value(%Instances{}, :bacon, "good")
    assert state.state_values == %{bacon: "good"}
  end

  test "get_state_value/2" do
    assert true == Instances.get_state_value(%Instances{state_values: %{flag: true}}, :flag)
  end

  test "subtract/4 when loser does not exist" do
    assert {:no_loser, state} = Instances.subtract(%Instances{}, :anything, 2, 12345)
  end

  test "subtract/4 health on a maptile" do
    wall       = %MapTile{id: 992, row: 1, col: 1, z_index: 0, character: "#", state: ""}
    breakable  = %MapTile{id: 993, row: 1, col: 2, z_index: 0, character: "B", state: "destroyable: true"}
    damageable = %MapTile{id: 994, row: 1, col: 3, z_index: 0, character: "D", state: "health: 10"}
    state = %Instances{instance_id: 12345}
    {wall, state} = Instances.create_map_tile(state, wall)
    {breakable, state} = Instances.create_map_tile(state, breakable)
    {damageable, state} = Instances.create_map_tile(state, damageable)

    dungeon_channel = "dungeons:12345"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    assert {:noop, updated_state} = Instances.subtract(state, :health, 5, wall.id)
    assert state == updated_state

    assert {:ok, updated_state} = Instances.subtract(state, :health, 5, breakable.id)
    refute Instances.get_map_tile_by_id(updated_state, breakable)
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 2, rendering: "<div> </div>"}]}}
    assert {:ok, updated_state} = Instances.subtract(state, :health, 5, damageable.id)
    assert Instances.get_map_tile_by_id(updated_state, damageable).parsed_state[:health] == 5
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 3, rendering: _anything}]}}
    assert {:ok, updated_state} = Instances.subtract(state, :health, 10, damageable.id)
    refute Instances.get_map_tile_by_id(updated_state, damageable)
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 3, rendering: "<div> </div>"}]}}
  end

  test "subtract/4 non health on a maptile" do
    map_tile = %MapTile{id: 992, row: 1, col: 1, z_index: 0, character: "#", state: "cash: 5"}
    {map_tile, state} = Instances.create_map_tile(%Instances{}, map_tile)

    assert {:ok, updated_state} = Instances.subtract(state, :cash, 5, map_tile.id)
    assert Instances.get_map_tile_by_id(updated_state, map_tile).parsed_state[:cash] == 0
    assert {:not_enough, updated_state} = Instances.subtract(state, :cash, 6, map_tile.id)
    assert state == updated_state
    assert {:not_enough, updated_state} = Instances.subtract(state, :nothing, 1, map_tile.id)
    assert state == updated_state
  end

  test "subtract/4 health on a player tile" do
    instance = insert_stubbed_dungeon_instance()
    player_tile = %MapTile{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "gems: 10, health: 30", script: "", map_instance_id: instance.id}
    location = %Location{id: 444, user_id_hash: "dubs", map_tile_instance_id: 123}
    state = %Instances{instance_id: 123}
    {player_tile, state} = Instances.create_player_map_tile(state, player_tile, location)

    dungeon_channel = "dungeons:123"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)
    player_channel = "players:444"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    assert {:ok, updated_state} = Instances.subtract(state, :health, 10, player_tile.id)
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: _anything}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{ammo: 0, cash: 0, gems: 10, health: 20, keys: ""}}}

    assert {:ok, updated_state} = Instances.subtract(state, :health, 30, player_tile.id)
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{col: 4, rendering: "<div>✝</div>", row: 4}]}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{ammo: 0, cash: 0, gems: 0, health: 0, keys: ""}}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "You died!"}}
  end

  test "subtract/4 non health on a player tile" do
    player_tile = %MapTile{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "gems: 10, health: 30", script: ""}
    location = %Location{id: 444, user_id_hash: "dubs", map_tile_instance_id: 123}
    state = %Instances{instance_id: 123}
    {player_tile, state} = Instances.create_player_map_tile(state, player_tile, location)

    player_channel = "players:444"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    assert {:ok, updated_state} = Instances.subtract(state, :gems, 10, player_tile.id)
    assert Instances.get_map_tile_by_id(updated_state, player_tile).parsed_state[:gems] == 0
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{ammo: 0, cash: 0, gems: 0, health: 30, keys: ""}}}

    assert {:not_enough, updated_state} = Instances.subtract(state, :gems, 12, player_tile.id)
    assert state == updated_state
    assert {:not_enough, updated_state} = Instances.subtract(state, :cash, 500, player_tile.id)
    assert state == updated_state
  end

  test "get_tile_template/2", %{state: state} do
    assert {nil, ^state, :not_found} = Instances.get_tile_template("fake_slug", state)

    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    # looks up from the database and caches it
    assert {bullet, updated_state, :created} = Instances.get_tile_template("bullet", state)
    assert bullet.name == "Bullet"
    assert updated_state == %{ state | tile_template_slug_cache: updated_state.tile_template_slug_cache}
    assert updated_state.tile_template_slug_cache["bullet"] == bullet

    # finds it in the cache and returns it
    assert {^bullet, ^updated_state, :exists} = Instances.get_tile_template("bullet", updated_state)

    # an id is given instead
    assert {nil, ^updated_state, :not_found} = Instances.get_tile_template(bullet.id, updated_state)
  end
end


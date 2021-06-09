defmodule DungeonCrawl.DungeonProcesses.LevelsTest do
  use DungeonCrawl.DataCase

  import ExUnit.CaptureLog

  alias DungeonCrawl.DungeonProcesses.{Levels, DungeonRegistry, DungeonProcess}
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Scores

  setup do
    tile =        %Tile{id: 999, row: 1, col: 2, z_index: 0, character: "B", state: "", script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#TAKE health, 100, ?sender\n#DIE"}
    tile_south_1  = %Tile{id: 997, row: 1, col: 3, z_index: 1, character: "S", state: "", script: ""}
    tile_south_2  = %Tile{id: 998, row: 1, col: 3, z_index: 0, character: "X", state: "", script: ""}

    {_, state} = Levels.create_tile(%Levels{}, tile)
    {_, state} = Levels.create_tile(state, tile_south_1)
    {_, state} = Levels.create_tile(state, tile_south_2)

    %{state: state}
  end

  test "the state looks right", %{state: state} do
    assert %Levels{
      program_contexts: %{999 => %{
                  event_sender: nil,
                  object_id: 999,
                  program: %DungeonCrawl.Scripting.Program{
                    broadcasts: [],
                    instructions: %{
                      1 => [:halt, [""]],
                      2 => [:noop, "TOUCH"],
                      3 => [:text, [["Hey"]]],
                      4 => [:halt, [""]],
                      5 => [:noop, "TERMINATE"],
                      6 => [:take, ["health", 100, [:event_sender]]],
                      7 => [:die, [""]]
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

  test "get_tile/2 gets the top tile at the given coordinates", %{state: state} do
    assert %{id: 999} = Levels.get_tile(state, %{row: 1, col: 2})
  end

  test "get_tile/3 gets the top tile in the given direction", %{state: state} do
    assert %{id: 997} = Levels.get_tile(state, %{row: 1, col: 2}, "east")
  end

  test "get_tiles/3 gets the tiles in the given direction", %{state: state} do
    assert [tile_1, tile_2] = Levels.get_tiles(state, %{row: 1, col: 2}, "east")
    assert %{id: 997} = tile_1
    assert %{id: 998} = tile_2
  end

  test "get_tiles/3 gets empty array in the given direction", %{state: state} do
    assert [] == Levels.get_tiles(state, %{row: 1, col: 2}, "north")
  end

  test "get_tile_by_id/2 gets the tile for the id", %{state: state} do
    assert %{id: 999} = Levels.get_tile_by_id(state, %{id: 999})
  end

  test "get_player_location/2", %{state: state} do
    player_tile = %Tile{id: 1, row: 4, col: 4, z_index: 1, character: "@"}
    location = %Location{user_id_hash: "dubs", tile_instance_id: 123}
    {player_tile, state} = Levels.create_player_tile(state, player_tile, location)

    # using a tile id
    assert Levels.get_player_location(state, %{id: player_tile.id}) == location
    refute Levels.get_player_location(state, %{id: 99999})

    # using user_id_hash
    assert Levels.get_player_location(state, "dubs") == location
    refute Levels.get_player_location(state, "notrealhash")
  end

  test "responds_to_event?/3", %{state: state} do
    assert Levels.responds_to_event?(state, %{id: 999}, "TOUCH")
    refute Levels.responds_to_event?(state, %{id: 999}, "SNIFF")
    refute Levels.responds_to_event?(state, %{id: 222}, "ANYTHING")
  end

  test "send_event/4 but its not a player sending it", %{state: state} do
    # doesn't run anything, just adds it to the program messages list
    sender = %{tile_id: nil, parsed_state: %{}, name: "global"}
    updated_state = Levels.send_event(state, 1337, "message", sender)
    assert updated_state.program_messages == [ {1337, "message", sender} ]
    assert Map.delete(updated_state, :program_messages) == Map.delete(state, :program_messages)
  end

  test "send_event/4", %{state: state} do
    li = insert_stubbed_level_instance()
    player_tile = %Tile{level_instance_id: li.id, id: 123, row: 4, col: 4, z_index: 1, character: "@", state: "health: 100, lives: 3, player: true"}
    player_location = %Location{id: 555, user_id_hash: "dubs", tile_instance_id: 123}
    {_player_tile, state} = Levels.create_player_tile(state, player_tile, player_location)

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    %Levels{ program_contexts: %{999 => %{program: program} },
                map_by_ids: _,
                map_by_coords: _ } = state

    # noop if it tile doesnt have a program
    updated_state = Levels.send_event(state, %{id: 111}, "TOUCH", player_location)
    %Levels{ program_contexts: %{999 => %{program: ^program} },
                map_by_ids: _,
                map_by_coords: _ } = updated_state

    # it does something
    updated_state_2 = Levels.send_event(updated_state, %{id: 999}, "TOUCH", player_location)
    %Levels{ program_contexts: %{999 => %{program: updated_program} },
                map_by_ids: _,
                map_by_coords: _ } = updated_state_2
    refute program == updated_program
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "Hey"}}

    # prunes the program if died during the run of the label
    updated_state_3 = Levels.send_event(updated_state_2, %{id: 999}, "TERMINATE", player_location)
    assert [new_tile_id] = Map.keys(updated_state_3.map_by_ids) -- Map.keys(updated_state_2.map_by_ids)

    %Levels{ program_contexts: program_contexts ,
                map_by_ids: _,
                map_by_coords: _ } = updated_state_3

    # dead player gets buried, but this also validates that new tile with program actually gets
    # added to the program contexts (and not lost)
    refute program_contexts[999]
    assert program_contexts[new_tile_id]
    assert updated_state_3.map_by_ids[new_tile_id].name == "Grave"
  end

  test "add_message_action/3" do
    state = Levels.set_message_actions(%Levels{}, 123, ["maybe", "ok"])
            |> Levels.set_message_actions(777, ["negative"])
    assert state.message_actions == %{123 => ["maybe", "ok"], 777 => ["negative"]}
  end

  test "remove_message_actions/2" do
    state = %Levels{ message_actions: %{123 => ["maybe", "ok"], 777 => ["negative"]} }
    updated_state = Levels.remove_message_actions(state, 123)
    refute Map.has_key?(updated_state, 123)
    assert updated_state.message_actions == %{ 777 => ["negative"] }
  end

  test "valid_message_action?/3" do
    state = %Levels{ message_actions: %{123 => ["maybe", "ok"], 777 => ["negative"]} }
    assert Levels.valid_message_action?(state, 123, "maybe")
    assert Levels.valid_message_action?(state, 777, "negative")
    refute Levels.valid_message_action?(state, 777, "ok")
    refute Levels.valid_message_action?(state, 999234, "ok")
  end

  test "create_player_tile/3 creates a player tile and regsiters it" do
    new_tile = %Tile{id: 1, row: 5, col: 4, z_index: 1, character: "@"}
    location = %Location{user_id_hash: "dubs", tile_instance_id: 123}

    {new_tile, state} = Levels.create_player_tile(%Levels{}, new_tile, location)

    assert %{id: 1, character: "@"} = new_tile
    assert %Levels{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_tile, :parsed_state, %{entry_col: 4, entry_row: 5})},
      map_by_coords: %{ {5, 4} => %{1 => 1} },
      player_locations: %{new_tile.id => location},
      rerender_coords: %{%{col: 4, row: 5} => true}
    } == Map.put(state, :dirty_ids, %{})

    # returns the existing tile if it already exists by id, but links player location
    assert {^new_tile, state} = Levels.create_player_tile(state, Map.put(new_tile, :character, "O"), location)
    assert %{id: 1, character: "@"} = new_tile
    assert %Levels{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_tile, :parsed_state, %{entry_col: 4, entry_row: 5})},
      map_by_coords: %{ {5, 4} => %{1 => 1} },
      player_locations: %{new_tile.id => location},
      rerender_coords: %{%{col: 4, row: 5} => true}
    } == Map.merge(state, %{dirty_ids: %{}, dirty_player_tile_stats: []})
  end

  test "create_tile/2 creates a tile" do
    new_tile = %{id: 1, row: 4, col: 4, z_index: 0, character: "M", state: "", script: ""}

    {new_tile, state} = Levels.create_tile(%Levels{}, new_tile)

    assert %{id: 1, character: "M"} = new_tile
    assert %Levels{
      program_contexts: %{},
      map_by_ids: %{1 =>  Map.put(new_tile, :parsed_state, %{})},
      map_by_coords: %{ {4, 4} => %{0 => 1} },
      new_pids: [],
      rerender_coords: %{%{col: 4, row: 4} => true}
    } == state

    # assigns a temporary id when it does not have one, which indicates this tile has not been persisted to the database yet
    assert {new_tile_1, updated_state} = Levels.create_tile(state, Map.merge(new_tile, %{id: nil, row: 5}))
    assert is_binary(new_tile_1.id)
    assert String.starts_with?(new_tile_1.id, "new_")
    assert updated_state.new_ids == %{new_tile_1.id => 0}

    # returns the existing tile if it already exists by id
    assert {^new_tile, ^state} = Levels.create_tile(state, Map.put(new_tile, :character, "O"))
    assert %{id: 1, character: "M"} = new_tile

    # Does not load a corrupt script (edge case - corrupt script shouldnt even get into the DB, and logs a warning
    tile_bad_script = %Tile{row: 1, col: 4, id: 123, script: "#NOT_A_REAL_COMMAND"}
    assert capture_log(fn ->
             assert {_tile, updated_state} = Levels.create_tile(state, tile_bad_script)
             assert %Levels{ program_contexts: %{},
                                map_by_ids: %{1 => Map.put(new_tile, :parsed_state, %{}),
                                              123 => Map.put(tile_bad_script, :parsed_state, %{})},
                                map_by_coords: %{{1, 4} => %{0 => 123}, {4, 4} => %{0 => 1}},
                                rerender_coords: %{%{col: 4, row: 1} => true, %{col: 4, row: 4} => true} } == updated_state
           end) =~ ~r/Possible corrupt script for tile instance:/

    # If there's a program that starts, adds the tile_id to new_pids, so Levels._cycle_program
    # can know to save it and add it back to the map of updated program_contexts.
    tile_good_script = %Tile{character: "U", row: 1, col: 4, id: 123, script: "#SHOOT north"}
    {new_tile, state} = Levels.create_tile(%Levels{}, tile_good_script)
    assert %{id: 123, character: "U"} = new_tile
    assert %Levels{
      program_contexts: %{123 => _},
      map_by_ids: %{123 => ^new_tile},
      map_by_coords: %{ {1, 4} => %{0 => 123} },
      new_pids: [ 123 ],
      rerender_coords: %{%{col: 4, row: 1} => true}
    } = state
  end

  test "set_tile_id/3" do
    tile = %{id: 1000, row: 3, col: 4, z_index: 0, character: "M", state: "", script: "#END"}
    {_tile, state} = Levels.create_tile(%Levels{}, tile)
    program_contexts = %{ 1000 => %{ program: %{state.program_contexts[1000].program |
                                                 messages: [{"touch", %{tile_id: "new_0"}},
                                                            {"touch", nil},
                                                            {"touch", Map.merge(%Location{}, %{parsed_state: {}} )}]},
                                     event_sender: %{tile_id: "new_0"} }}
    state = %{ state | program_contexts: program_contexts }

    new_tile = %{id: nil, row: 4, col: 4, z_index: 0, character: "M", state: "blocking: true", script: "#END\n:touch\nHI"}
    {new_tile, state} = Levels.create_tile(state, new_tile)
    assert new_tile.id == "new_0"

    # noop if the new id is not and int or the old id is not a binary
    assert ^state = Levels.set_tile_id(state, %{id: "new_0"}, "new_0")
    assert ^state = Levels.set_tile_id(state, %{id: 1}, 2)

    # stuff gets updated
    assert updated_state = Levels.set_tile_id(state, Map.put(new_tile, :id, 1), new_tile.id)
    assert Map.delete(updated_state.map_by_ids[1], :id) == Map.delete(state.map_by_ids[new_tile.id], :id)
    refute updated_state.map_by_ids[1].id == new_tile.id
    assert is_integer(updated_state.map_by_ids[1].id)
    assert updated_state.map_by_coords[{4,4}] == %{0 => 1}
    assert %{1 => %{object_id: 1}} = updated_state.program_contexts
    refute updated_state.program_contexts[new_tile.id]

    assert updated_state.program_contexts[1000].program.messages == [{"touch", %{tile_id: 1}},
                                                                     {"touch", nil},
                                                                     {"touch", Map.merge(%Location{}, %{parsed_state: {}})}]
    assert updated_state.program_contexts[1000].event_sender == %{tile_id: 1}
  end

  test "set_tile_id/3 when new tile has no script" do
    new_tile = %{id: nil, row: 4, col: 4, z_index: 0, character: "M", state: "blocking: true", script: ""}
    {new_tile, state} = Levels.create_tile(%Levels{}, new_tile)
    assert new_tile.id == "new_0"

    # noop if the new id is not and int or the old id is not a binary
    assert ^state = Levels.set_tile_id(state, %{id: "new_0"}, "new_0")
    assert ^state = Levels.set_tile_id(state, %{id: 1}, 2)

    # stuff gets updated
    assert updated_state = Levels.set_tile_id(state, Map.put(new_tile, :id, 1), new_tile.id)
    assert Map.delete(updated_state.map_by_ids[1], :id) == Map.delete(state.map_by_ids[new_tile.id], :id)
    refute updated_state.map_by_ids[1].id == new_tile.id
    assert is_integer(updated_state.map_by_ids[1].id)
    assert updated_state.map_by_coords[{4,4}] == %{0 => 1}
    assert %{} == updated_state.program_contexts
  end

  test "update_tile_state/3", %{state: state} do
    tile = Levels.get_tile(state, %{id: 999, row: 1, col: 2})
    assert {tile, state} = Levels.update_tile_state(state, tile, %{hamburders: 4})
    assert tile.parsed_state[:hamburders] == 4
    assert tile.state == "hamburders: 4"

    assert {tile, _state} = Levels.update_tile_state(state, tile, %{coffee: 2})
    assert tile.parsed_state[:hamburders] == 4
    assert tile.parsed_state[:coffee] == 2
    assert tile.state == "coffee: 2, hamburders: 4"
  end

  test "update_tile/3 updates the tile", %{state: state} do
    tile = Levels.get_tile(state, %{id: 999, row: 1, col: 2})
    new_attributes = %{id: 333, row: 2, col: 2, character: "M"}

    assert {updated_tile, updated_state} = Levels.update_tile(state, tile, new_attributes)
    assert Map.merge(tile, %{row: 2, col: 2, character: "M"}) == updated_tile
    assert %{dirty_ids: %{999 => changeset}} = updated_state
    assert changeset.changes == Tile.changeset(tile,%{character: "M", row: 2}).changes
  end

  test "update_tile/3", %{state: state} do
    tile_id = 999
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: tile_id}, %{id: 11111, character: "X", row: 1, col: 1})
    assert %{id: ^tile_id, character: "X", row: 1, col: 1} = state.map_by_ids[tile_id]
    assert %{dirty_ids: %{999 => changeset}} = state
    assert changeset.changes == Tile.changeset(%Tile{},%{character: "X", col: 1}).changes

    # Move to an empty space
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: tile_id}, %{row: 2, col: 3})
    assert %{id: ^tile_id, character: "X", row: 2, col: 3} = state.map_by_ids[tile_id]
    assert %{dirty_ids: %{999 => changeset}} = state
    assert changeset.changes == Tile.changeset(%Tile{},%{character: "X", row: 2, col: 3}).changes

    # Move ontop of another tile
    another_tile = %Tile{id: -3, character: "O", row: 5, col: 6, z_index: 0}
    {_another_tile, state} = Levels.create_tile(state, another_tile)

    # Won't move to the same z_index
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: tile_id}, %{row: 5, col: 6})
    assert %Tile{id: ^tile_id, character: "X", row: 2, col: 3, z_index: 0} = state.map_by_ids[tile_id]
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: tile_id}, %{row: 5, col: 6, z_index: 1})
    assert %Tile{id: ^tile_id, character: "X", row: 5, col: 6, z_index: 1} = state.map_by_ids[tile_id]
    assert %Tile{id: -3, character: "O", row: 5, col: 6, z_index: 0} = state.map_by_ids[-3]

    # Move the new tile
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: -3}, %{character: "M"})
    assert %{dirty_ids: %{999 => changeset_999, -3 => changeset_neg_3}} = state
    assert changeset_999.changes == Tile.changeset(%Tile{},%{character: "X", row: 5, col: 6, z_index: 1}).changes
    assert changeset_neg_3.changes == Tile.changeset(%Tile{},%{character: "M"}).changes

    # Adds a program
    refute state.program_contexts[-3]
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: -3}, %{script: "#END\n:TOUCH\n?s"})
    assert %{-3 => %{program: program, object_id: -3}} = state.program_contexts
    assert %{map_by_ids: %{-3 => %Tile{script: "#END\n:TOUCH\n?s"}}} = state
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
    assert {_updated_tile, state} = Levels.update_tile(state, %{id: 999}, %{script: "?n"})
    assert %{999 => %{program: program, object_id: 999}} = state.program_contexts
    assert %{map_by_ids: %{999 => %Tile{script: "?n"}}} = state
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

  test "delete_player_tile/2 deletes the tile and unregisters player location", %{state: state} do
    tile_id = 999
    tile = state.map_by_ids[tile_id]

    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord } = state
    state = %{ state | player_locations: %{ tile_id => %Location{} }}
    assert programs[tile.id]
    assert by_id[tile.id]
    assert %{ {1, 2} => %{ 0 => ^tile_id} } = by_coord

    assert {_deleted_tile, state} = Levels.delete_tile(state, tile)
    refute state.map_by_ids[tile_id]
    refute state.player_locations[tile_id]
    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord,
             dirty_ids: %{^tile_id => :deleted},
             player_locations: player_locations } = state
    refute programs[tile_id]
    refute by_id[tile_id]
    assert %{ {1, 2} => %{} } = by_coord
    assert %{} == player_locations
  end

  test "delete_player_tile/3 removes the tile and unregisters player location, but does not mark for deletion", %{state: state} do
    tile_id = 999
    tile = state.map_by_ids[tile_id]

    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord } = state
    state = %{ state | player_locations: %{ tile_id => %Location{} }}
    assert programs[tile.id]
    assert by_id[tile.id]
    assert %{ {1, 2} => %{ 0 => ^tile_id} } = by_coord

    assert {_deleted_tile, state} = Levels.delete_tile(state, tile, false) # false parameter
    refute state.map_by_ids[tile_id]
    refute state.player_locations[tile_id]
    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord,
             dirty_ids: %{}, # the only other thing different from the above test
             player_locations: player_locations } = state
    refute programs[tile_id]
    refute by_id[tile_id]
    assert %{ {1, 2} => %{} } = by_coord
    assert %{} == player_locations
  end

  test "delete_tile/2 deletes the tile", %{state: state} do
    tile_id = 999
    tile = state.map_by_ids[tile_id]
    state = %{ state | passage_exits: [{tile_id, "tunnel_a"}] }

    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord,
             passage_exits: passage_exits } = state
    assert programs[tile.id]
    assert by_id[tile.id]
    assert %{ {1, 2} => %{ 0 => ^tile_id} } = by_coord
    assert passage_exits == [{tile_id, "tunnel_a"}]

    assert {_deleted_tile, state} = Levels.delete_tile(state, tile)
    refute state.map_by_ids[tile_id]
    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord,
             dirty_ids: %{^tile_id => :deleted},
             passage_exits: passage_exits } = state
    refute programs[tile_id]
    refute by_id[tile_id]
    assert passage_exits == []
    assert %{ {1, 2} => %{} } = by_coord
  end

  test "direction_of_tile/3" do
    tile_nw = %Tile{id: 990, row: 2, col: 2, z_index: 0, character: "."}
    tile_n  = %Tile{id: 991, row: 2, col: 3, z_index: 0, character: "#", state: "blocking: true"}
    tile_ne = %Tile{id: 992, row: 2, col: 4, z_index: 0, character: "."}
    tile_w  = %Tile{id: 993, row: 3, col: 2, z_index: 0, character: "#", state: "blocking: true"}
    tile_me = %Tile{id: 994, row: 3, col: 3, z_index: 0, character: "@"}
    tile_e  = %Tile{id: 995, row: 3, col: 4, z_index: 0, character: "."}
    tile_sw = %Tile{id: 996, row: 4, col: 2, z_index: 0, character: "."}
    tile_s  = %Tile{id: 997, row: 4, col: 3, z_index: 0, character: "."}
    tile_se = %Tile{id: 998, row: 4, col: 4, z_index: 0, character: "."}

    {_, state} = Levels.create_tile(%Levels{}, tile_nw)
    {_, state} = Levels.create_tile(state, tile_n)
    {_, state} = Levels.create_tile(state, tile_ne)
    {_, state} = Levels.create_tile(state, tile_w)
    {_, state} = Levels.create_tile(state, tile_me)
    {_, state} = Levels.create_tile(state, tile_e)
    {_, state} = Levels.create_tile(state, tile_sw)
    {_, state} = Levels.create_tile(state, tile_s)
    {_, state} = Levels.create_tile(state, tile_se)

    # If target is at same coords as object, idle
    assert Levels.direction_of_tile(state, tile_me, tile_me) == "idle"
    # Target inline but is blocked, still returns the direction
    assert Levels.direction_of_tile(state, tile_me, tile_n) == "north"
    assert Levels.direction_of_tile(state, tile_me, tile_w) == "west"
    # Target inline and unblocked
    assert Levels.direction_of_tile(state, tile_me, tile_s) == "south"
    assert Levels.direction_of_tile(state, tile_me, tile_e) == "east"
    # Target is in a diagonal direction, preference given to the non blocked
    assert Levels.direction_of_tile(state, tile_me, tile_ne) == "east"
    assert Levels.direction_of_tile(state, tile_me, tile_sw) == "south"
    # Target is in a diagonal direction, non blocked, one is picked
    assert Enum.member?(["south", "east"], Levels.direction_of_tile(state, tile_me, tile_se))
    # Target is in a diagonal direction, both blocked, one is picked
    assert Enum.member?(["north", "west"], Levels.direction_of_tile(state, tile_me, tile_nw))
  end

  test "is_player_tile?/2" do
    player_tile = %Tile{id: 1, row: 4, col: 4, z_index: 1, character: "@"}
    other_tile = %Tile{id: 998, row: 4, col: 4, z_index: 0, character: "."}
    location = %Location{user_id_hash: "dubs", tile_instance_id: 123}

    {player_tile, state} = Levels.create_player_tile(%Levels{}, player_tile, location)
    {other_tile, state} = Levels.create_tile(state, other_tile)

    assert Levels.is_player_tile?(state, player_tile)
    refute Levels.is_player_tile?(state, other_tile)
    refute Levels.is_player_tile?(state, %{id: 236346565456})
  end

  test "set_state_value/3" do
    state = Levels.set_state_value(%Levels{}, :bacon, "good")
    assert state.state_values == %{bacon: "good"}
  end

  test "get_state_value/2" do
    assert true == Levels.get_state_value(%Levels{state_values: %{flag: true}}, :flag)
  end

  test "subtract/4 when loser does not exist" do
    assert {:no_loser, _state} = Levels.subtract(%Levels{}, :anything, 2, 12345)
  end

  test "subtract/4 health on a tile" do
    wall       = %Tile{id: 992, row: 1, col: 1, z_index: 0, character: "#", state: ""}
    breakable  = %Tile{id: 993, row: 1, col: 2, z_index: 0, character: "B", state: "destroyable: true"}
    damageable = %Tile{id: 994, row: 1, col: 3, z_index: 0, character: "D", state: "health: 10"}
    state = %Levels{dungeon_instance_id: 14, instance_id: 12345}
    {wall, state} = Levels.create_tile(state, wall)
    {breakable, state} = Levels.create_tile(state, breakable)
    {damageable, state} = Levels.create_tile(state, damageable)

    dungeon_channel = "dungeons:14:12345"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    assert {:noop, updated_state} = Levels.subtract(state, :health, 5, wall.id)
    assert state == updated_state

    assert {:died, updated_state} = Levels.subtract(state, :health, 5, breakable.id)
    refute Levels.get_tile_by_id(updated_state, breakable)
    assert Map.has_key? updated_state.rerender_coords, Map.take(breakable, [:row, :col])

    assert {:ok, updated_state} = Levels.subtract(state, :health, 5, damageable.id)
    assert Levels.get_tile_by_id(updated_state, damageable).parsed_state[:health] == 5
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 3, rendering: _anything}]}}

    assert {:died, updated_state} = Levels.subtract(state, :health, 10, damageable.id)
    refute Levels.get_tile_by_id(updated_state, damageable)
    assert Map.has_key? updated_state.rerender_coords, Map.take(damageable, [:row, :col])
  end

  test "subtract/4 non health on a tile" do
    tile = %Tile{id: 992, row: 1, col: 1, z_index: 0, character: "#", state: "cash: 5"}
    {tile, state} = Levels.create_tile(%Levels{}, tile)

    assert {:ok, updated_state} = Levels.subtract(state, :cash, 5, tile.id)
    assert Levels.get_tile_by_id(updated_state, tile).parsed_state[:cash] == 0
    assert {:not_enough, updated_state} = Levels.subtract(state, :cash, 6, tile.id)
    assert state == updated_state
    assert {:not_enough, updated_state} = Levels.subtract(state, :nothing, 1, tile.id)
    assert state == updated_state
  end

  test "subtract/4 health on a player tile" do
    instance = insert_stubbed_level_instance()
    player_tile = %Tile{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "gems: 10, health: 30, lives: 2", script: "", level_instance_id: instance.id}
    location = %Location{id: 444, user_id_hash: "dubs", tile_instance_id: 123}
    state = %Levels{dungeon_instance_id: 14, instance_id: 123}
    {player_tile, state} = Levels.create_player_tile(state, player_tile, location)

    dungeon_channel = "dungeons:14:123"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)
    player_channel = "players:444"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    assert {:ok, updated_state} = Levels.subtract(state, :health, 10, player_tile.id)
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: _anything}
    assert Enum.member? updated_state.dirty_player_tile_stats, player_tile.id

    assert {:ok, updated_state} = Levels.subtract(state, :health, 30, player_tile.id)
    assert Map.has_key? updated_state.rerender_coords, Map.take(player_tile, [:row, :col])
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "You died!"}}
    assert Enum.member? updated_state.dirty_player_tile_stats, player_tile.id
  end

  test "subtract/4 health on a player tile when instance reset_player_when_damaged sv is true" do
    instance = insert_stubbed_level_instance(%{state_values: "reset_player_when_damaged: true"})
    player_tile = %Tile{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "gems: 10, health: 30, lives: 2", level_instance_id: instance.id}
    location = %Location{id: 444, user_id_hash: "dubs", tile_instance_id: 123}
    state = %Levels{dungeon_instance_id: 14, instance_id: 123, state_values: %{reset_player_when_damaged: true}}
    {player_tile, state} = Levels.create_player_tile(state, player_tile, location)
    {player_tile, state} = Levels.update_tile_state(state, player_tile, %{entry_row: 1, entry_col: 9})

    assert {:ok, updated_state} = Levels.subtract(state, :health, 10, player_tile.id)

    player_tile = Levels.get_tile_by_id(updated_state, player_tile)
    assert %{row: 1, col: 9} = player_tile
    assert  %{%{col: 4, row: 4} => true, %{col: 9, row: 1} => true} = updated_state.rerender_coords
  end

  test "subtract/4 non health on a player tile" do
    player_tile = %Tile{id: 1, row: 4, col: 4, z_index: 1, character: "@", state: "gems: 10, health: 30"}
    location = %Location{id: 444, user_id_hash: "dubs", tile_instance_id: 123}
    state = %Levels{instance_id: 123}
    {player_tile, state} = Levels.create_player_tile(state, player_tile, location)

    player_channel = "players:444"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    assert {:ok, updated_state} = Levels.subtract(state, :gems, 10, player_tile.id)
    assert Levels.get_tile_by_id(updated_state, player_tile).parsed_state[:gems] == 0
    assert Enum.member? updated_state.dirty_player_tile_stats, player_tile.id

    assert {:not_enough, updated_state} = Levels.subtract(state, :gems, 12, player_tile.id)
    assert state == updated_state
    assert {:not_enough, updated_state} = Levels.subtract(state, :cash, 500, player_tile.id)
    assert state == updated_state
  end

  test "get_tile_template/2", %{state: state} do
    assert {nil, ^state, :not_found} = Levels.get_tile_template("fake_slug", state)

    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    # looks up from the database and caches it
    assert {bullet, updated_state, :created} = Levels.get_tile_template("bullet", state)
    assert bullet.name == "Bullet"
    assert updated_state == %{ state | tile_template_slug_cache: updated_state.tile_template_slug_cache}
    assert updated_state.tile_template_slug_cache["bullet"] == bullet

    # finds it in the cache and returns it
    assert {^bullet, ^updated_state, :exists} = Levels.get_tile_template("bullet", updated_state)

    # an id is given instead / template not found
    assert {nil, ^updated_state, :not_found} = Levels.get_tile_template(bullet.id, updated_state)

    # template cannot be since dungeon has author whom is not an admin nor owner of the non public slug
    DungeonCrawl.TileTemplates.update_tile_template(bullet, %{user_id: insert_user().id})
    state = %{state | author: %{id: 1, is_admin: false}}
    assert {nil, ^state, :not_found} = Levels.get_tile_template("bullet", state)
  end

  test "gameover/3 - ends game for all players in instance" do
    instance = insert_stubbed_level_instance(%{}, [
                 %Tile{character: "@", row: 1, col: 3, state: "damage: 10, player: true, score: 3, steps: 10", name: "player"},
                 %Tile{character: "@", row: 1, col: 4, state: "damage: 10, player: true, score: 1, steps: 99", name: "player"}
               ])
    [player_tile_1, player_tile_2] = Repo.preload(instance, :tiles).tiles
                                     |> Enum.sort(fn a, b -> a.col < b.col end)

    player_location_1 = %Location{id: 12,
                                  tile_instance_id: player_tile_1.id,
                                  inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now, -13),
                                  user_id_hash: "goober"}

    player_location_2 = %Location{id: 13,
                                  tile_instance_id: player_tile_1.id,
                                  inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now, -3),
                                  user_id_hash: "goober2"}

    state = %Levels{state_values: %{rows: 20, cols: 20}, dungeon_instance_id: instance.dungeon_instance_id}
    {player_tile_1, state} = Levels.create_player_tile(state, player_tile_1, player_location_1)
    {player_tile_2, state} = Levels.create_player_tile(state, player_tile_2, player_location_2)

    player_channel_1 = "players:#{player_location_1.id}"
    player_channel_2 = "players:#{player_location_2.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel_1)
    DungeonCrawlWeb.Endpoint.subscribe(player_channel_2)

    dungeon_id = Repo.preload(instance, :dungeon).dungeon.dungeon_id
    {:ok, map_set_process} = DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, state.dungeon_instance_id)

    # Ends game for all players in instance
    updated_state = Levels.gameover(state, true, "Win")

    [score_1, score_2] = Scores.list_scores
    score_1_id = score_1.id
    score_2_id = score_2.id

    assert %{parsed_state: %{gameover: true, score_id: ^score_1_id}} =
      Levels.get_tile_by_id(updated_state, player_tile_1)
    assert %{parsed_state: %{gameover: true, score_id: ^score_2_id}} =
      Levels.get_tile_by_id(updated_state, player_tile_2)
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_1,
            event: "gameover",
            payload: %{score_id: ^score_1_id, dungeon_id: ^dungeon_id}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_2,
            event: "gameover",
            payload: %{score_id: ^score_2_id, dungeon_id: ^dungeon_id}}
    assert %{user_id_hash: "goober",
             score: 3,
             steps: 10,
             dungeon_id: ^dungeon_id,
             victory: true,
             result: "Win"} = score_1
    assert %{user_id_hash: "goober2",
             score: 1,
             steps: 99,
             dungeon_id: ^dungeon_id,
             victory: true,
             result: "Win"} = score_2

    # doesn't make new scores when the tiles already have gameover state
    Levels.gameover(updated_state, player_tile_1.id, true, "Won Still")

    assert Scores.list_scores == [score_1, score_2]

    Scores.list_scores |> Enum.map(&(Repo.delete(&1)))

    # no scoring
    DungeonProcess.set_state_value(map_set_process, :no_scoring, true)
    Levels.gameover(state, true, "Done")

    assert Scores.list_scores == []

    #cleanup
    DungeonRegistry.remove(DungeonInstanceRegistry, instance.dungeon_instance_id)
  end

  test "gameover/4 - ends game for given player" do
    instance = insert_stubbed_level_instance(%{}, [
                 %Tile{character: "@", row: 1, col: 3, state: "damage: 10, player: true, score: 3, steps: 10", name: "player"},
                 %Tile{character: "@", row: 1, col: 4, state: "damage: 10, player: true, score: 1, steps: 99", name: "player"}
               ])
    [player_tile_1, player_tile_2] = Repo.preload(instance, :tiles).tiles
                                     |> Enum.sort(fn a, b -> a.col < b.col end)

    player_location_1 = %Location{id: 12,
                                  tile_instance_id: player_tile_1.id,
                                  inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now, -13),
                                  user_id_hash: "goober"}

    player_location_2 = %Location{id: 13,
                                  tile_instance_id: player_tile_1.id,
                                  inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now, -3),
                                  user_id_hash: "goober2"}

    state = %Levels{state_values: %{rows: 20, cols: 20}, dungeon_instance_id: instance.dungeon_instance_id}
    {player_tile_1, state} = Levels.create_player_tile(state, player_tile_1, player_location_1)
    {player_tile_2, state} = Levels.create_player_tile(state, player_tile_2, player_location_2)

    player_channel_1 = "players:#{player_location_1.id}"
    player_channel_2 = "players:#{player_location_2.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel_1)
    DungeonCrawlWeb.Endpoint.subscribe(player_channel_2)

    dungeon_id = Repo.preload(instance, :dungeon).dungeon.dungeon_id
    {:ok, map_set_process} = DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, state.dungeon_instance_id)

    # default gameover - player gets victory
    updated_state = Levels.gameover(state, player_tile_1.id, true, "Win")

    score = Scores.list_scores |> Enum.reverse |> Enum.at(0)
    score_id = score.id

    assert %{parsed_state: %{gameover: true, score_id: ^score_id}} =
      Levels.get_tile_by_id(updated_state, player_tile_1)
    refute Levels.get_tile_by_id(updated_state, player_tile_2).parsed_state[:gameover]
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_1,
            event: "gameover",
            payload: %{score_id: ^score_id, dungeon_id: ^dungeon_id}}
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_2}
    assert %{user_id_hash: "goober",
             score: 3,
             steps: 10,
             dungeon_id: ^dungeon_id,
             victory: true,
             result: "Win"} = score

    # doesn't make new scores when the tiles already have gameover state
    updated_state = Levels.gameover(updated_state, player_tile_1.id, true, "Won Still")

    assert [score] == Scores.list_scores
    assert %{parsed_state: %{gameover: true, score_id: ^score_id}} =
      Levels.get_tile_by_id(updated_state, player_tile_1)
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_1,
            event: "gameover",
            payload: %{score_id: ^score_id, dungeon_id: ^dungeon_id}}
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_2}

    Scores.list_scores |> Enum.map(&(Repo.delete(&1)))

    # no scoring
    DungeonProcess.set_state_value(map_set_process, :no_scoring, true)
    updated_state = Levels.gameover(state, player_tile_1.id, true, "Done")

    assert Scores.list_scores == []

    assert %{parsed_state: %{gameover: true}} =
      Levels.get_tile_by_id(updated_state, player_tile_1)
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel_1,
            event: "gameover",
            payload: %{}}

    #cleanup
    DungeonRegistry.remove(DungeonInstanceRegistry, instance.dungeon_instance_id)
  end
end


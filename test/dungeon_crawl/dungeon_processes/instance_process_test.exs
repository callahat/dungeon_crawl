defmodule DungeonCrawl.InstanceProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Player.Location

  require DungeonCrawl.InstancesMockFactory

  # A lot of these tests are semi redundant, as the code that actually modifies the state lives
  # in the Instances module. Testing this also effectively hits the Instances code,
  # which also has its own set of similar tests.

  setup do
    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    {:ok, instance_process} = InstanceProcess.start_link([])
    map_instance = insert_stubbed_dungeon_instance(
                     %{},
                     [%MapTile{character: "O", row: 1, col: 1, z_index: 0, script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#TERMINATE"}])
    map_tile = DungeonCrawl.Repo.get_by(MapTile, %{map_instance_id: map_instance.id})

    InstanceProcess.set_instance_id(instance_process, map_instance.id)
    InstanceProcess.set_map_set_instance_id(instance_process, map_instance.map_set_instance_id)
    InstanceProcess.load_map(instance_process, [map_tile])
    InstanceProcess.set_state_values(instance_process, %{rows: 20, cols: 20})

    %{instance_process: instance_process, map_tile_id: map_tile.id, map_instance: map_instance}
  end

  test "set_instance_id" do
    {:ok, instance_process} = InstanceProcess.start_link([])
    map_instance = insert_stubbed_dungeon_instance()
    map_instance_id = map_instance.id
    InstanceProcess.set_instance_id(instance_process, map_instance_id)
    assert %{ instance_id: ^map_instance_id } = InstanceProcess.get_state(instance_process)
  end

  test "set_map_set_instance_id" do
    {:ok, instance_process} = InstanceProcess.start_link([])
    map_instance = insert_stubbed_dungeon_instance()
    map_set_instance_id = map_instance.map_set_instance_id
    InstanceProcess.set_map_set_instance_id(instance_process, map_set_instance_id)
    assert %{ map_set_instance_id: ^map_set_instance_id } = InstanceProcess.get_state(instance_process)
  end

  test "set_level_number" do
    {:ok, instance_process} = InstanceProcess.start_link([])
    map_instance = insert_stubbed_dungeon_instance()
    number = map_instance.number
    InstanceProcess.set_level_number(instance_process, number)
    assert %{ number: ^number } = InstanceProcess.get_state(instance_process)
  end

  test "set_adjacent_map_id" do
    {:ok, instance_process} = InstanceProcess.start_link([])
    InstanceProcess.set_adjacent_map_id(instance_process, 1, "north")
    assert %{ adjacent_map_ids: %{"north" => 1} } = InstanceProcess.get_state(instance_process)
  end

  test "set_state_values" do
    {:ok, instance_process} = InstanceProcess.start_link([])
    InstanceProcess.set_state_values(instance_process, %{flag: false})
    assert %{ state_values: %{flag: false} } = InstanceProcess.get_state(instance_process)
  end

  test "load_map", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    map_tile_with_script = %MapTile{id: 236, character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"}
    map_tiles = [%MapTile{id: 123, character: "O", row: 1, col: 1, z_index: 0},
                 map_tile_with_script]

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    # Starts the program(s) for the tiles, no script nothing done for that tile.
    assert %Instances{ program_contexts: programs,
                       map_by_ids: by_id,
                       map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    assert %{^map_tile_id => %{event_sender: nil,
                       object_id: ^map_tile_id,
                       program: %Program{status: :alive}},
             236 => %{event_sender: nil,
                       object_id: 236,
                       program: %Program{status: :alive}}
            } = programs

    # Does not load a program overtop an already running program for that map_tile id
    assert :ok = InstanceProcess.load_map(instance_process, [%MapTile{id: map_tile_id, script: "#DIE"}])
    assert %Instances{ program_contexts: ^programs,
                       map_by_ids: ^by_id,
                       map_by_coords: ^by_coord,
                       new_pids: [236, ^map_tile_id],
                       instance_id: _ } = InstanceProcess.get_state(instance_process)
  end

  test "load_spawn_coordinates", %{instance_process: instance_process} do
    assert :ok = InstanceProcess.load_spawn_coordinates(instance_process, [{1,1}, {2,3}, {4,5}])
    assert %Instances{ spawn_coordinates: spawn_coordinates } = InstanceProcess.get_state(instance_process)
    assert Enum.sort([{1,1}, {2,3}, {4,5}]) == Enum.sort(spawn_coordinates)
  end

  test "start_scheduler", %{instance_process: instance_process} do
    # Starts the scheduler that will run every xxx ms and run the next parts of all the programs
    InstanceProcess.start_scheduler(instance_process)
  end

  test "inspect_state returns a listing of running programs", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert %Instances{ program_contexts: programs,
                       map_by_ids: _,
                       map_by_coords: _ } = InstanceProcess.get_state(instance_process)
    assert %{^map_tile_id => %{event_sender: nil,
                       object_id: ^map_tile_id,
                       program: %Program{status: :alive}}
            } = programs
  end

  test "responds_to_event?", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert InstanceProcess.responds_to_event?(instance_process, map_tile_id, "TOUCH")
    refute InstanceProcess.responds_to_event?(instance_process, map_tile_id, "SNIFF")
    refute InstanceProcess.responds_to_event?(instance_process, map_tile_id-1, "ANYTHING")
  end

  test "send_event/3", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    scripted_tile_1 = %MapTile{id: 236, character: "O", row: 1, col: 2, z_index: 0, script: "#end\n:alert\n#become color: red"}
    scripted_tile_2 = %MapTile{id: 237, character: "O", row: 1, col: 3, z_index: 0, script: "#end\n:alert\n#become color: yellow"}
    inert_tile = %MapTile{id: 238, character: "O", row: 1, col: 3, z_index: 0, script: "#end\n:alert\n#become color: yellow"}

    assert :ok = InstanceProcess.load_map(instance_process, [scripted_tile_1, scripted_tile_2, inert_tile])

    sender = %{map_tile_id: nil, parsed_state: %{}, name: "global"}

    %Instances{ program_contexts: program_contexts } = InstanceProcess.get_state(instance_process)

    # sends the message to all running programs
    InstanceProcess.send_event(instance_process, "TOUCH", sender)
    %Instances{ program_contexts: ^program_contexts,
                program_messages: program_messages } = InstanceProcess.get_state(instance_process)

    assert Enum.member?(program_messages, {map_tile_id, "TOUCH", sender})
    assert Enum.member?(program_messages, {scripted_tile_1.id, "TOUCH", sender})
    assert Enum.member?(program_messages, {scripted_tile_2.id, "TOUCH", sender})
    refute Enum.member?(program_messages, {inert_tile.id, "TOUCH", sender})
  end

  test "send_event/4", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    player_location = %Location{id: 555}

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    %Instances{ program_contexts: %{^map_tile_id => %{program: program} },
                map_by_ids: _,
                map_by_coords: _ } = InstanceProcess.get_state(instance_process)

    # noop if it tile doesnt have a program
    InstanceProcess.send_event(instance_process, 111, "TOUCH", player_location)
    %Instances{ program_contexts: %{^map_tile_id => %{program: same_program} },
                map_by_ids: _,
                map_by_coords: _ } = InstanceProcess.get_state(instance_process)
    assert program == same_program

    # it does something
    InstanceProcess.send_event(instance_process, map_tile_id, "TOUCH", player_location)
    %Instances{ program_contexts: %{^map_tile_id => %{program: updated_program} },
                map_by_ids: _,
                map_by_coords: _ } = InstanceProcess.get_state(instance_process)
    refute program == updated_program
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "Hey"}}

    # prunes the program if died during the run of the label
    InstanceProcess.send_event(instance_process, map_tile_id, "TERMINATE", player_location)
    %Instances{ program_contexts: %{} ,
                map_by_ids: _,
                map_by_coords: _ } = InstanceProcess.get_state(instance_process)
  end

  test "perform_actions", %{instance_process: instance_process, map_instance: map_instance} do
    dungeon_channel = "dungeons:#{map_instance.map_set_instance_id}:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SHOOT east"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white\n#SEND touch, all"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "#TERMINATE"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    # These tiles will be needed later
    shooter_tile_id = InstanceProcess.get_tile(instance_process, 1, 2).id
    east_tile_id = InstanceProcess.get_tile(instance_process, 1, 3).id
    eastest_tile_id = InstanceProcess.get_tile(instance_process, 1, 4).id

    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel}

    assert :ok = Process.send(instance_process, :perform_actions, [])

    # Sanity check that the programs are all there, including the one for the generated bullet
    bullet_tile_id = InstanceProcess.get_tile(instance_process, 1, 2).id

    assert state = InstanceProcess.get_state(instance_process)
    # this should still be active
    assert %{program: %{status: :alive}} = state.program_contexts[bullet_tile_id]
    # these will be idle
    assert %{program: %{status: :idle}} = state.program_contexts[shooter_tile_id]
    assert %{program: %{status: :idle}} = state.program_contexts[east_tile_id]
    # This one is dead and removed from the contexts
    refute state.program_contexts[eastest_tile_id]

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{col: 2, rendering: "<div style='color: red'>O</div>", row: 1},
                               %{col: 3, rendering: "<div style='color: white'>M</div>", row: 1}]}}
    # These were either idle or had no script
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 1}]}}
  end

  test "perform_actions adds messages to programs", %{instance_process: instance_process,
                                                      map_instance: map_instance,
                                                      map_tile_id: map_tile_id} do
    dungeon_channel = "dungeons:#{map_instance.map_set_instance_id}:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    tt = insert_tile_template()

    map_tiles = [
        %{name: "a", character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"},
        %{name: "b", character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white\n#SEND touch, all"},
        %{name: "c", character: "O", row: 1, col: 4, z_index: 0, script: ""}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)
    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Instances{ program_contexts: program_contexts ,
                program_messages: program_messages } = InstanceProcess.get_state(instance_process)
    assert [] == program_messages # should be cleared after punting the messages to the actual progams

    # The last map tile in this setup has no active program
    expected = %{ map_tile_id => [{"touch", %{map_tile_id: Enum.at(map_tiles,1).id, parsed_state: %{}, name: "b"}}],
                  Enum.at(map_tiles,0).id => [{"touch", %{map_tile_id: Enum.at(map_tiles,1).id, parsed_state: %{}, name: "b"}}],
                  Enum.at(map_tiles,1).id => [{"touch", %{map_tile_id: Enum.at(map_tiles,1).id, parsed_state: %{}, name: "b"}}] }

    actual = program_contexts
             |> Map.to_list
             |> Enum.map(fn {id, context} -> {id, context.program.messages} end)
             |> Enum.into(%{})

    assert actual == expected
  end

  test "perform_actions handles dealing with health when a tile is damaged", %{instance_process: instance_process,
                                                                               map_instance: map_instance} do
    dungeon_channel = "dungeons:#{map_instance.map_set_instance_id}:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#SEND shot, a nonprog\n#SEND bombed, player", state: "damage: 5"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "", state: "health: 10", name: "a nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, script: "", state: "health: 10, lives: 2", name: "player"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    _shooter_map_tile = Enum.at(map_tiles, 0)
    non_prog_tile = Enum.at(map_tiles, 1)
    player_tile = Enum.at(map_tiles, 2)

    player_location = %Location{id: 555, map_tile_instance_id: player_tile.id}
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    InstanceProcess.run_with(instance_process, fn(state) ->
      Instances.create_player_map_tile(state, player_tile, player_location)
    end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Instances{ map_by_ids: map_by_ids,
                dirty_ids: _dirty_ids } = InstanceProcess.get_state(instance_process)

    # Wounded tiles
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{health: 5}}}

    assert map_by_ids[non_prog_tile.id].parsed_state[:health] == 5
    assert map_by_ids[player_tile.id].parsed_state[:health] == 5

    shooter2 = DungeonInstances.create_map_tile!(%{
      character: "O",
      row: 1,
      col: 2,
      z_index: 1,
      script: "#SEND shot, a nonprog\n#SEND shot, player",
      state: "damage: 5",
      map_instance_id: map_instance.id})

    assert :ok = InstanceProcess.load_map(instance_process, [shooter2])

    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Instances{ map_by_ids: map_by_ids,
                dirty_ids: dirty_ids } = InstanceProcess.get_state(instance_process)

    # Dead tiles
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{health: 0}}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "You died!"}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: tiles}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: updated_tiles}}
    assert Enum.member? tiles, %{row: 1, col: 3, rendering: "<div>@</div>"}
    assert Enum.member? updated_tiles, %{row: 1, col: 3, rendering: "<div>✝</div>"}

    refute map_by_ids[non_prog_tile.id]
    assert map_by_ids[player_tile.id].parsed_state[:health] == 0
    assert map_by_ids[player_tile.id].parsed_state[:buried]
    assert :ok = Process.send(instance_process, :perform_actions, [])

    non_prog_tile_id = non_prog_tile.id
    player_tile_id = player_tile.id
    assert dirty_ids[non_prog_tile_id] == :deleted
    refute dirty_ids[player_tile_id] == :deleted
  end

  test "perform_actions handles behavior 'destroyable'", %{instance_process: instance_process,
                                                           map_instance: map_instance,
                                                           map_tile_id: map_tile_id} do
    dungeon_channel = "dungeons:#{map_instance.map_set_instance_id}:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    tt = insert_tile_template()

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SEND shot, others\n#SEND shot, a nonprog", state: "destroyable: true"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "", state: "destroyable: true", name: "a nonprog"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    shooter_map_tile_id = Enum.at(map_tiles, 0).id
    non_prog_tile_id = Enum.at(map_tiles, 1).id

    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id, %{state: "destroyable: true"})
    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)
    assert :ok = Process.send(instance_process, :perform_actions, [])

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 4, rendering: "<div> </div>"}]}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 1, rendering: "<div> </div>"}]}}

    %Instances{ program_contexts: program_contexts,
                map_by_ids: map_by_ids,
                dirty_ids: dirty_ids } = InstanceProcess.get_state(instance_process)

    assert [ ^shooter_map_tile_id ] = Map.keys(program_contexts)
    assert [ ^shooter_map_tile_id ] = Map.keys(map_by_ids)
    assert %{ ^map_tile_id => :deleted, ^non_prog_tile_id => :deleted} = dirty_ids
  end

  test "perform_actions standard_behavior point awarding", %{instance_process: instance_process,
                                                             map_instance: map_instance} do
    map_tiles = [
        %{character: "B", row: 1, col: 2, z_index: 0, script: "#SEND shot, another nonprog", state: "damage: 5", name: "damager"},
        %{character: "O", row: 1, col: 4, z_index: 0, state: "health: 10, points: 9", name: "a nonprog"},
        %{character: "O", row: 1, col: 9, z_index: 0, state: "destroyable: true, points: 5", name: "another nonprog"},
        %{character: "O", row: 1, col: 5, z_index: 0, script: "#SEND shot, worthless nonprog", state: "destroyable: true, owner: 23423, points: 3", name: "worthless nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, script: "#SEND shot, a nonprog", state: "damage: 10", name: "player"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    damager_tile = Enum.at(map_tiles, 0)
    healty_tile = Enum.at(map_tiles, 1)
    destroyable_tile = Enum.at(map_tiles, 2)
    worthless_tile = Enum.at(map_tiles, 3)
    player_tile = Enum.at(map_tiles, 4)

    player_location = %Location{id: 555, map_tile_instance_id: player_tile.id}
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    InstanceProcess.run_with(instance_process, fn(state) ->
      Instances.create_player_map_tile(state, player_tile, player_location)
    end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    assert :ok = InstanceProcess.update_tile(instance_process, damager_tile.id, %{state: "damage: 15, owner: #{ player_tile.id }"})

    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Instances{ map_by_ids: map_by_ids } = InstanceProcess.get_state(instance_process)

    refute map_by_ids[healty_tile.id]
    refute map_by_ids[destroyable_tile.id]
    refute map_by_ids[worthless_tile.id]
    refute map_by_ids[damager_tile.id].parsed_state[:score]
    assert map_by_ids[player_tile.id].parsed_state[:score] == 14

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{score: 14}}}
  end

  test "perform_actions rendering when map has fog", %{instance_process: instance_process, map_instance: map_instance} do
    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SHOOT east"},
        %{character: "O", row: 1, col: 10, z_index: 0, script: "#BECOME character: M\n#BECOME color: white"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "#BECOME character: .\n#TERMINATE"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)
    assert :ok = InstanceProcess.set_state_values(instance_process, %{visibility: "fog"})

    player_tile = DungeonInstances.create_map_tile!(
                    %{character: "@",
                      row: 2,
                      col: 3,
                      name: "player",
                      map_instance_id: map_instance.id})

    player_location = %Location{id: player_tile.id, map_tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    InstanceProcess.run_with(instance_process, fn(state) ->
      {_, state} = Instances.create_player_map_tile(state, player_tile, player_location)
      {:ok, %{ state | players_visible_coords: %{player_tile.id => [%{row: 1, col: 10}]}}}
    end)

    # subscribe
    dungeon_channel = "dungeons:#{map_instance.map_set_instance_id}:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # should have nothing until after sending :perform_actions
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel}
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel}

    assert :ok = Process.send(instance_process, :perform_actions, [])

    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "visible_tiles",
            payload: %{fog: [%{col: 10, row: 1}],
                       tiles: [%{col: 1, rendering: "<div>O</div>", row: 1},
                               %{col: 2, rendering: "<div>◦</div>", row: 1},
                               %{col: 3, rendering: "<div>@</div>", row: 2},
                               %{col: 4, rendering: "<div>.</div>", row: 1}]}}
  end

  test "check_on_inactive_players", %{instance_process: instance_process, map_instance: map_instance} do
    player_tile = DungeonInstances.create_map_tile!(
                    %{character: "@",
                      row: 1,
                      col: 3,
                      z_index: 0,
                      script: "",
                      state: "health: 10",
                      name: "player",
                      map_instance_id: map_instance.id})
    other_player_tile = DungeonInstances.create_map_tile!(
                          %{row: 1,
                            col: 3,
                            map_instance_id: map_instance.id})

    player_location = %Location{id: player_tile.id, map_tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    other_player_location = %Location{id: other_player_tile.id, map_tile_instance_id: other_player_tile.id, user_id_hash: "otherhash"}

    InstanceProcess.run_with(instance_process, fn(state) ->
      {_, state} = Map.put(state, :inactive_players, %{player_tile.id => 5, other_player_tile.id => 0})
                   |> Instances.create_player_map_tile(player_tile, player_location)
      Instances.create_player_map_tile(state, other_player_tile, other_player_location)
    end)

    # old player is petrified
    :ok = Process.send(instance_process, :check_on_inactive_players, [])

    %Instances{ inactive_players: inactive_players,
                player_locations: player_locations } = InstanceProcess.get_state(instance_process)

    assert %{other_player_tile.id => 1} == inactive_players
    assert player_locations == %{other_player_tile.id => other_player_location} # petrified and removed; this function tested elsewhere

    # doesn't break when running on a player that isnt' there anymore
    InstanceProcess.run_with(instance_process, fn(state) ->
      {:ok, Map.put(state, :inactive_players, %{player_tile.id => 5, other_player_tile.id => 0})}
    end)

    :ok = Process.send(instance_process, :check_on_inactive_players, [])

    %Instances{ inactive_players: inactive_players,
                player_locations: player_locations } = InstanceProcess.get_state(instance_process)

    assert %{other_player_tile.id => 1} == inactive_players
    assert player_locations == %{other_player_tile.id => other_player_location} # petrified and removed; this function tested elsewhere
  end

  test "write_db", %{instance_process: instance_process, map_instance: map_instance} do
    tt = insert_tile_template()

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white"},
        %{id: 123, character: "O", row: 1, col: 4, z_index: 0}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    new_map_tiles = [
        %{character: "N", row: 1, col: 5, z_index: 0, script: "#BECOME color: red"},
        %{character: "G", row: 1, col: 6, z_index: 0, script: "#BECOME color: gray"},
        %{character: "M", row: 1, col: 7, z_index: 0, script: "#BECOME color: red"},
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> {:ok, mt} = DungeonInstances.new_map_tile(mt); mt end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles ++ new_map_tiles)

    [map_tile_id_1, map_tile_id_2, map_tile_id_3] = map_tiles |> Enum.map(fn(mt) -> mt.id end)

    new_map_tile_1 = InstanceProcess.get_tile(instance_process, 1, 5)
    new_map_tile_2 = InstanceProcess.get_tile(instance_process, 1, 7)
    older_new_map_tile = InstanceProcess.get_tile(instance_process, 1, 6)

    InstanceProcess.run_with(instance_process, fn (instance_state) ->
      {:ok, %{ instance_state | new_ids: %{instance_state.new_ids | older_new_map_tile.id => 2 }}}
    end)

    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id_1, %{character: "Y", row: 2, col: 3})
    assert :ok = InstanceProcess.delete_tile(instance_process, map_tile_id_2)
    assert :ok = InstanceProcess.delete_tile(instance_process, new_map_tile_1.id)

    assert :ok = Process.send(instance_process, :write_db, [])
    :timer.sleep 10 # let the process do its thing
    assert "Y" == Repo.get(MapTile, map_tile_id_1).character
    refute Repo.get(MapTile, map_tile_id_2)
    assert "O" == Repo.get(MapTile, map_tile_id_3).character

    # new map tiles younger than 2 write_db iterations don't get persisted to the DB yet
    assert new_map_tile_2 == InstanceProcess.get_tile(instance_process, 1, 7)
    assert is_binary(new_map_tile_2.id)
    persisted_older_new_map_tile = InstanceProcess.get_tile(instance_process, 1, 6)
    # new map tiles that live past 2 or more write_db iterations get persisted to the DB
    assert is_integer(persisted_older_new_map_tile.id)
    assert "G" == Repo.get(MapTile, persisted_older_new_map_tile.id).character
  end

  test "get_tile/2 gets a tile by its id", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert %MapTile{id: map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = InstanceProcess.get_tile(instance_process, map_tile_id)
  end

  test "get_tile/3 gets the top tile for the row, col coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = InstanceProcess.get_tile(instance_process, 1, 1)
  end

  test "get_tile/3 gets nil if no tiles at the given coordinates", %{instance_process: instance_process} do
    refute InstanceProcess.get_tile(instance_process, -1, -1)
  end

  test "get_tile/4 gets the top tile in the direction from the row, col coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = InstanceProcess.get_tile(instance_process, 1, 1, "here")
  end

# get tiles

  test "get_tiles/3 gets the top tile for the row, col coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert [map_tile] = InstanceProcess.get_tiles(instance_process, 1, 1)
    assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = map_tile
  end

  test "get_tiles/3 gets emtpy array if no tiles at the given coordinates", %{instance_process: instance_process} do
    assert [] == InstanceProcess.get_tiles(instance_process, -1, -1)
  end

  test "get_tiles/4 gets the top tile in the direction from the row, col coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert [map_tile] = InstanceProcess.get_tiles(instance_process, 1, 1, "here")
    assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = map_tile
  end
# end get tiles

  test "update_tile/3", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id, %{id: 11111, character: "X", row: 1, col: 1})
    assert %MapTile{id: ^map_tile_id, character: "X", row: 1, col: 1, map_instance_id: m_id} = InstanceProcess.get_tile(instance_process, map_tile_id)

    # Move to an empty space
    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id, %{character: "Y", row: 2, col: 3})
    assert %MapTile{id: ^map_tile_id, character: "Y", row: 2, col: 3} = InstanceProcess.get_tile(instance_process, map_tile_id)

    # Move ontop of another tile
    another_map_tile = %MapTile{id: -3, character: "O", row: 5, col: 6, z_index: 0, map_instance_id: m_id}
    InstanceProcess.load_map(instance_process, [another_map_tile])

    # Won't move to the same z_index
    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id, %{row: 5, col: 6})
    assert %MapTile{id: ^map_tile_id, character: "Y", row: 2, col: 3, z_index: 0} = InstanceProcess.get_tile(instance_process, map_tile_id)
    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id, %{row: 5, col: 6, z_index: 1})
    assert %MapTile{id: ^map_tile_id, character: "Y", row: 5, col: 6, z_index: 1} = InstanceProcess.get_tile(instance_process, map_tile_id)
    assert %MapTile{id: -3, character: "O", row: 5, col: 6, z_index: 0} = InstanceProcess.get_tile(instance_process, another_map_tile.id)
  end

  test "delete_tile/2", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    assert programs[map_tile_id]
    assert by_id[map_tile_id]
    assert %{ {1, 1} => %{ 0 => ^map_tile_id} } = by_coord

    assert :ok = InstanceProcess.delete_tile(instance_process, map_tile_id)
    refute InstanceProcess.get_tile(instance_process, map_tile_id)
    %Instances{ program_contexts: programs,
                map_by_ids: by_id,
                map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    refute programs[map_tile_id]
    refute by_id[map_tile_id]
    assert %{ {1, 1} => %{} } = by_coord
  end

  test "gameover/3", %{instance_process: instance_process, map_instance: map_instance} do
    {:module, instances_mock_mod, _, _} = DungeonCrawl.InstancesMockFactory.generate(self())

    map_tiles = [
        %{character: "B", row: 1, col: 2, z_index: 0, state: "damage: 5", name: "damager"},
        %{character: "O", row: 1, col: 4, z_index: 0, state: "health: 10, points: 9", name: "a nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, state: "damage: 10", name: "player"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    player_tile_1 = Enum.at(map_tiles, 0)
    player_tile_2 = Enum.at(map_tiles, 2)

    player_location_1 = %Location{id: 555, map_tile_instance_id: player_tile_1.id}
    player_location_2 = %Location{id: 556, map_tile_instance_id: player_tile_2.id}

    InstanceProcess.run_with(instance_process, fn(state) ->
      {_, state} = Instances.create_player_map_tile(state, player_tile_1, player_location_1)
      Instances.create_player_map_tile(state, player_tile_2, player_location_2)
    end)

    %Instances{ instance_id: instance_id } = InstanceProcess.get_state(instance_process)

    InstanceProcess.gameover(instance_process, false, "loss", instances_mock_mod)

    assert_receive {:gameover_test, ^instance_id, false, "loss"}

    # cleanup
    :code.purge instances_mock_mod
    :code.delete instances_mock_mod
  end

  test "run_with/2", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    new_tile = %MapTile{id: 999, row: 1, col: 1, z_index: 1, character: "K"}
    return_value = InstanceProcess.run_with(instance_process, fn (state) ->
                     Instances.create_map_tile(state, new_tile)
                   end)
    assert return_value == Map.put(new_tile, :parsed_state, %{})
    %Instances{ program_contexts: _programs,
                map_by_ids: _by_id,
                map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    assert %{ {1, 1} => %{ 0 => ^map_tile_id, 1 => 999} } = by_coord
  end
end

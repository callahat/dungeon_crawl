defmodule DungeonCrawl.LevelProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Level
  alias DungeonCrawl.DungeonProcesses.Cache
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scores

  alias DungeonCrawl.Test.LevelsMockFactory

  # A lot of these tests are semi redundant, as the code that actually modifies the state lives
  # in the Levels module. Testing this also effectively hits the Levels code,
  # which also has its own set of similar tests.

  setup do
    DungeonCrawl.TileTemplates.TileSeeder.BasicTiles.bullet_tile

    {:ok, cache} = Cache.start_link([])
    {:ok, instance_process} = LevelProcess.start_link([])
    level_instance = insert_stubbed_level_instance(
                       %{},
                       [%Tile{character: "O", row: 1, col: 1, z_index: 0, script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#TERMINATE"}])
    tile = DungeonCrawl.Repo.get_by(Tile, %{level_instance_id: level_instance.id})

    LevelProcess.set_cache(instance_process, cache)
    LevelProcess.set_instance_id(instance_process, level_instance.id)
    LevelProcess.set_level_number(instance_process, level_instance.number)
    LevelProcess.set_player_location_id(instance_process, level_instance.player_location_id)
    LevelProcess.set_dungeon_instance_id(instance_process, level_instance.dungeon_instance_id)
    LevelProcess.load_level(instance_process, [tile])
    LevelProcess.set_state_values(instance_process, %{rows: 20, cols: 20})

    %{instance_process: instance_process, tile_id: tile.id, level_instance: level_instance}
  end

  test "set_instance_id" do
    {:ok, instance_process} = LevelProcess.start_link([])
    level_instance = insert_stubbed_level_instance()
    level_instance_id = level_instance.id
    LevelProcess.set_instance_id(instance_process, level_instance_id)
    assert %{ instance_id: ^level_instance_id } = LevelProcess.get_state(instance_process)
  end

  test "set_dungeon_instance_id" do
    {:ok, instance_process} = LevelProcess.start_link([])
    level_instance = insert_stubbed_level_instance()
    dungeon_instance_id = level_instance.dungeon_instance_id
    LevelProcess.set_dungeon_instance_id(instance_process, dungeon_instance_id)
    assert %{ dungeon_instance_id: ^dungeon_instance_id } = LevelProcess.get_state(instance_process)
  end

  test "set_level_number" do
    {:ok, instance_process} = LevelProcess.start_link([])
    level_instance = insert_stubbed_level_instance()
    number = level_instance.number
    LevelProcess.set_level_number(instance_process, number)
    assert %{ number: ^number } = LevelProcess.get_state(instance_process)
  end

  test "set_owner_id" do
    {:ok, instance_process} = LevelProcess.start_link([])
    level_instance = insert_stubbed_level_instance(%{player_location_id: 123})
    player_location_id = level_instance.player_location_id
    LevelProcess.set_player_location_id(instance_process, player_location_id)
    assert %{ player_location_id: ^player_location_id } = LevelProcess.get_state(instance_process)
  end

  test "set_author" do
    {:ok, instance_process} = LevelProcess.start_link([])
    author = %{is_admin: false, id: 23}
    LevelProcess.set_author(instance_process, author)
    assert %{ author: ^author } = LevelProcess.get_state(instance_process)
  end

  test "set_cache" do
    {:ok, cache} = Cache.start_link([])
    {:ok, instance_process} = LevelProcess.start_link([])
    LevelProcess.set_cache(instance_process, cache)
    assert %{ cache: ^cache } = LevelProcess.get_state(instance_process)
  end

  test "set_adjacent_level_numbers" do
    {:ok, instance_process} = LevelProcess.start_link([])
    LevelProcess.set_adjacent_level_numbers(instance_process, %{"north" => 1, "south" => nil})
    assert %{ adjacent_level_numbers: %{"north" => 1, "south" => nil} } = LevelProcess.get_state(instance_process)
  end

  test "set_state_values" do
    {:ok, instance_process} = LevelProcess.start_link([])
    LevelProcess.set_state_values(instance_process, %{flag: false})
    assert %{ state_values: %{flag: false} } = LevelProcess.get_state(instance_process)
  end

  test "load_level", %{instance_process: instance_process, tile_id: tile_id} do
    tile_with_script = %Tile{id: 236, character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"}
    tiles = [%Tile{id: 123, character: "O", row: 1, col: 1, z_index: 0},
             tile_with_script]

    assert :ok = LevelProcess.load_level(instance_process, tiles)

    # Starts the program(s) for the tiles, no script nothing done for that tile.
    assert %Levels{ program_contexts: programs,
                    map_by_ids: by_id,
                    map_by_coords: by_coord } = LevelProcess.get_state(instance_process)
    assert %{^tile_id => %{event_sender: nil,
                       object_id: ^tile_id,
                       program: %Program{status: :alive}},
             236 => %{event_sender: nil,
                       object_id: 236,
                       program: %Program{status: :alive}}
            } = programs

    # Does not load a program overtop an already running program for that tile id
    assert :ok = LevelProcess.load_level(instance_process, [%Tile{id: tile_id, script: "#DIE"}])
    assert %Levels{ program_contexts: ^programs,
                    map_by_ids: ^by_id,
                    map_by_coords: ^by_coord,
                    new_pids: [236, ^tile_id],
                    instance_id: _ } = LevelProcess.get_state(instance_process)
  end

  test "set_passage_exits", %{instance_process: instance_process} do
    LevelProcess.set_passage_exits(instance_process, [{123, "Vermilion"}, {4, "red"}])

    assert [{123, "Vermilion"}, {4, "red"}] == LevelProcess.get_state(instance_process).passage_exits
  end

  test "load_program_contexts", %{instance_process: instance_process} do
    assert LevelProcess.load_program_contexts(instance_process, nil) == false
    assert LevelProcess.load_program_contexts(instance_process, %{}) == false
    assert LevelProcess.load_program_contexts(instance_process, %{123 => %{}}) == true

    assert %{123 => %{}} == LevelProcess.get_state(instance_process).program_contexts
  end

  test "load_spawn_coordinates", %{instance_process: instance_process} do
    assert :ok = LevelProcess.load_spawn_coordinates(instance_process, [{1,1}, {2,3}, {4,5}])
    assert %Levels{ spawn_coordinates: spawn_coordinates } = LevelProcess.get_state(instance_process)
    assert Enum.sort([{1,1}, {2,3}, {4,5}]) == Enum.sort(spawn_coordinates)
  end

  test "inspect_state returns a listing of running programs", %{instance_process: instance_process, tile_id: tile_id} do
    assert %Levels{ program_contexts: programs,
                    map_by_ids: _,
                    map_by_coords: _ } = LevelProcess.get_state(instance_process)
    assert %{^tile_id => %{event_sender: nil,
                       object_id: ^tile_id,
                       program: %Program{status: :alive}}
            } = programs
  end

  test "responds_to_event?", %{instance_process: instance_process, tile_id: tile_id} do
    assert LevelProcess.responds_to_event?(instance_process, tile_id, "TOUCH")
    refute LevelProcess.responds_to_event?(instance_process, tile_id, "SNIFF")
    refute LevelProcess.responds_to_event?(instance_process, tile_id-1, "ANYTHING")
  end

  test "send_event/3", %{instance_process: instance_process, tile_id: tile_id} do
    scripted_tile_1 = %Tile{id: 236, character: "O", row: 1, col: 2, z_index: 0, script: "#end\n:alert\n#become color: red"}
    scripted_tile_2 = %Tile{id: 237, character: "O", row: 1, col: 3, z_index: 0, script: "#end\n:alert\n#become color: yellow"}
    inert_tile = %Tile{id: 238, character: "O", row: 1, col: 3, z_index: 0, script: "#end\n:alert\n#become color: yellow"}

    assert :ok = LevelProcess.load_level(instance_process, [scripted_tile_1, scripted_tile_2, inert_tile])

    sender = %{tile_id: nil, parsed_state: %{}, name: "global"}

    %Levels{ program_contexts: program_contexts } = LevelProcess.get_state(instance_process)

    # sends the message to all running programs
    LevelProcess.send_event(instance_process, "TOUCH", sender)
    %Levels{ program_contexts: ^program_contexts,
             program_messages: program_messages } = LevelProcess.get_state(instance_process)

    assert Enum.member?(program_messages, {tile_id, "TOUCH", sender})
    assert Enum.member?(program_messages, {scripted_tile_1.id, "TOUCH", sender})
    assert Enum.member?(program_messages, {scripted_tile_2.id, "TOUCH", sender})
    refute Enum.member?(program_messages, {inert_tile.id, "TOUCH", sender})
  end

  test "send_event/4", %{instance_process: instance_process, tile_id: tile_id} do
    player_location = %Location{id: 555}

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    %Levels{ program_contexts: %{^tile_id => %{program: program} },
             map_by_ids: _,
             map_by_coords: _ } = LevelProcess.get_state(instance_process)

    # noop if it tile doesnt have a program
    LevelProcess.send_event(instance_process, 111, "TOUCH", player_location)
    %Levels{ program_contexts: %{^tile_id => %{program: same_program} },
             map_by_ids: _,
             map_by_coords: _ } = LevelProcess.get_state(instance_process)
    assert program == same_program

    # it does something
    LevelProcess.send_event(instance_process, tile_id, "TOUCH", player_location)
    %Levels{ program_contexts: %{^tile_id => %{program: updated_program} },
             map_by_ids: _,
             map_by_coords: _ } = LevelProcess.get_state(instance_process)
    refute program == updated_program
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "Hey"}}

    # prunes the program if died during the run of the label
    LevelProcess.send_event(instance_process, tile_id, "TERMINATE", player_location)
    %Levels{ program_contexts: %{} ,
             map_by_ids: _,
             map_by_coords: _ } = LevelProcess.get_state(instance_process)
  end

  test "perform_actions", %{instance_process: instance_process, level_instance: level_instance} do
    level_channel = _level_channel(level_instance)
    DungeonCrawlWeb.Endpoint.subscribe(level_channel)

    tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SHOOT east"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white\n#SEND touch, all"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "#TERMINATE"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    assert :ok = LevelProcess.load_level(instance_process, tiles)

    # These tiles will be needed later
    shooter_tile_id = LevelProcess.get_tile(instance_process, 1, 2).id
    east_tile_id = LevelProcess.get_tile(instance_process, 1, 3).id
    eastest_tile_id = LevelProcess.get_tile(instance_process, 1, 4).id

    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel}

    assert :ok = Process.send(instance_process, :perform_actions, [])

    # Sanity check that the programs are all there, including the one for the generated bullet
    bullet_tile_id = LevelProcess.get_tile(instance_process, 1, 2).id

    assert state = LevelProcess.get_state(instance_process)
    # this should still be active
    assert %{program: %{status: :alive}} = state.program_contexts[bullet_tile_id]
    # these will be idle
    assert %{program: %{status: :idle}} = state.program_contexts[shooter_tile_id]
    assert %{program: %{status: :idle}} = state.program_contexts[east_tile_id]
    # This one is dead and removed from the contexts
    refute state.program_contexts[eastest_tile_id]

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel,
            event: "tile_changes",
            payload: %{tiles: [%{col: 2, rendering: "<div style='color: red'>O</div>", row: 1},
                               %{col: 3, rendering: "<div style='color: white'>M</div>", row: 1}]}}
    # These were either idle or had no script
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel,
            payload: %{tiles: [%{row: 1, col: 1}]}}
  end

  test "perform_actions adds messages to programs", %{instance_process: instance_process,
                                                      level_instance: level_instance,
                                                      tile_id: tile_id} do
    level_channel = _level_channel(level_instance)
    DungeonCrawlWeb.Endpoint.subscribe(level_channel)

    tt = insert_tile_template()

    tiles = [
        %{name: "a", character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"},
        %{name: "b", character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white\n#SEND touch, all"},
        %{name: "c", character: "O", row: 1, col: 4, z_index: 0, script: ""}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    assert :ok = LevelProcess.load_level(instance_process, tiles)
    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Levels{ program_contexts: program_contexts ,
             program_messages: program_messages } = LevelProcess.get_state(instance_process)
    assert [] == program_messages # should be cleared after punting the messages to the actual progams

    # The last tile in this setup has no active program
    expected = %{ tile_id => [{"touch", %{tile_id: Enum.at(tiles,1).id, parsed_state: %{}, name: "b"}}],
                  Enum.at(tiles,0).id => [{"touch", %{tile_id: Enum.at(tiles,1).id, parsed_state: %{}, name: "b"}}],
                  Enum.at(tiles,1).id => [{"touch", %{tile_id: Enum.at(tiles,1).id, parsed_state: %{}, name: "b"}}] }

    actual = program_contexts
             |> Map.to_list
             |> Enum.map(fn {id, context} -> {id, context.program.messages} end)
             |> Enum.into(%{})

    assert actual == expected
  end

  test "perform_actions handles dealing with health when a tile is damaged", %{instance_process: instance_process,
                                                                               level_instance: level_instance} do
    level_channel = _level_channel(level_instance)
    DungeonCrawlWeb.Endpoint.subscribe(level_channel)

    tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#SEND shot, a nonprog\n#SEND bombed, player", state: "damage: 5"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "", state: "health: 10", name: "a nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, script: "", state: "health: 10, lives: 2", name: "player"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    _shooter_tile = Enum.at(tiles, 0)
    non_prog_tile = Enum.at(tiles, 1)
    player_tile = Enum.at(tiles, 2)

    player_location = %Location{id: 555, tile_instance_id: player_tile.id}
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    LevelProcess.run_with(instance_process, fn(state) ->
      Levels.create_player_tile(state, player_tile, player_location)
    end)

    assert :ok = LevelProcess.load_level(instance_process, tiles)

    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Levels{ map_by_ids: map_by_ids,
             dirty_ids: _dirty_ids } = LevelProcess.get_state(instance_process)

    # Wounded tiles
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{health: 5}}}

    assert map_by_ids[non_prog_tile.id].parsed_state[:health] == 5
    assert map_by_ids[player_tile.id].parsed_state[:health] == 5

    shooter2 = DungeonInstances.create_tile!(%{
      character: "O",
      row: 1,
      col: 2,
      z_index: 1,
      script: "#SEND shot, a nonprog\n#SEND shot, player",
      state: "damage: 5",
      level_instance_id: level_instance.id})

    assert :ok = LevelProcess.load_level(instance_process, [shooter2])

    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Levels{ map_by_ids: map_by_ids,
             dirty_ids: dirty_ids } = LevelProcess.get_state(instance_process)

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
            topic: ^level_channel,
            event: "tile_changes",
            payload: %{tiles: tiles}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel,
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
                                                           level_instance: level_instance,
                                                           tile_id: tile_id} do
    level_channel = _level_channel(level_instance)
    DungeonCrawlWeb.Endpoint.subscribe(level_channel)

    tt = insert_tile_template()

    tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SEND shot, others\n#SEND shot, a nonprog", state: "destroyable: true"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "", state: "destroyable: true", name: "a nonprog"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    shooter_tile_id = Enum.at(tiles, 0).id
    non_prog_tile_id = Enum.at(tiles, 1).id

    assert :ok = LevelProcess.update_tile(instance_process, tile_id, %{state: "destroyable: true"})
    assert :ok = LevelProcess.load_level(instance_process, tiles)
    assert :ok = Process.send(instance_process, :perform_actions, [])

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 1, rendering: "<div> </div>"},
                               %{col: 2, rendering: "<div style='color: red'>O</div>", row: 1},
                               %{row: 1, col: 4, rendering: "<div> </div>"}]}}

    %Levels{ program_contexts: program_contexts,
             map_by_ids: map_by_ids,
             dirty_ids: dirty_ids } = LevelProcess.get_state(instance_process)

    assert [ ^shooter_tile_id ] = Map.keys(program_contexts)
    assert [ ^shooter_tile_id ] = Map.keys(map_by_ids)
    assert %{ ^tile_id => :deleted, ^non_prog_tile_id => :deleted} = dirty_ids
  end

  test "perform_actions standard_behavior point awarding", %{instance_process: instance_process,
                                                             level_instance: level_instance} do
    tiles = [
        %{character: "B", row: 1, col: 2, z_index: 0, script: "#SEND shot, another nonprog", state: "damage: 5", name: "damager"},
        %{character: "O", row: 1, col: 4, z_index: 0, state: "health: 10, points: 9", name: "a nonprog"},
        %{character: "O", row: 1, col: 9, z_index: 0, state: "destroyable: true, points: 5", name: "another nonprog"},
        %{character: "O", row: 1, col: 5, z_index: 0, script: "#SEND shot, worthless nonprog", state: "destroyable: true, owner: 23423, points: 3", name: "worthless nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, script: "#SEND shot, a nonprog", state: "damage: 10", name: "player"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    damager_tile = Enum.at(tiles, 0)
    healty_tile = Enum.at(tiles, 1)
    destroyable_tile = Enum.at(tiles, 2)
    worthless_tile = Enum.at(tiles, 3)
    player_tile = Enum.at(tiles, 4)

    player_location = %Location{id: 555, tile_instance_id: player_tile.id}
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)
    LevelProcess.run_with(instance_process, fn(state) ->
      Levels.create_player_tile(state, player_tile, player_location)
    end)

    assert :ok = LevelProcess.load_level(instance_process, tiles)

    assert :ok = LevelProcess.update_tile(instance_process, damager_tile.id, %{state: "damage: 15, owner: #{ player_tile.id }"})

    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Levels{ map_by_ids: map_by_ids } = LevelProcess.get_state(instance_process)

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

  test "perform_actions rendering when level has fog", %{instance_process: instance_process, level_instance: level_instance} do
    tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SHOOT east"},
        %{character: "O", row: 1, col: 10, z_index: 0, script: "#BECOME character: M\n#BECOME color: white"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "#BECOME character: .\n#TERMINATE"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    assert :ok = LevelProcess.load_level(instance_process, tiles)
    assert :ok = LevelProcess.set_state_values(instance_process, %{visibility: "fog"})

    player_tile = DungeonInstances.create_tile!(
                    %{character: "@",
                      row: 2,
                      col: 3,
                      name: "player",
                      level_instance_id: level_instance.id})

    player_location = %Location{id: player_tile.id, tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    LevelProcess.run_with(instance_process, fn(state) ->
      {_, state} = Levels.create_player_tile(state, player_tile, player_location)
      {:ok, %{ state | players_visible_coords: %{player_tile.id => [%{row: 1, col: 10}]}}}
    end)

    # subscribe
    level_channel = _level_channel(level_instance)
    DungeonCrawlWeb.Endpoint.subscribe(level_channel)
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # should have nothing until after sending :perform_actions
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel}
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel}

    assert :ok = Process.send(instance_process, :perform_actions, [])

    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^level_channel}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "visible_tiles",
            payload: %{fog: [%{col: 10, row: 1}],
                       tiles: [%{col: 1, rendering: "<div>O</div>", row: 1},
                               %{col: 2, rendering: "<div>◦</div>", row: 1},
                               %{col: 3, rendering: "<div>@</div>", row: 2},
                               %{col: 4, rendering: "<div>.</div>", row: 1}]}}
  end

  test "perform_actions broadcasting sound", %{instance_process: instance_process, level_instance: level_instance} do
    expected_zzfx_params = ",0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04"
    sound_effect = insert_effect(%{zzfx_params: expected_zzfx_params})

    tiles = [
              %{character: "O", row: 1, col: 2, z_index: 0, script: "#SOUND #{sound_effect.slug}, all"}
            ]
            |> Enum.map(fn(mt) -> Map.merge(mt, %{level_instance_id: level_instance.id}) end)
            |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    assert :ok = LevelProcess.load_level(instance_process, tiles)
    assert :ok = LevelProcess.set_state_values(instance_process, %{visibility: "fog"})

    player_tile = DungeonInstances.create_tile!(
      %{character: "@",
        row: 2,
        col: 3,
        name: "player",
        level_instance_id: level_instance.id})

    player_location = %Location{id: player_tile.id, tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    LevelProcess.run_with(instance_process, fn(state) ->
      {_, state} = Levels.create_player_tile(state, player_tile, player_location)
      {:ok, state}
    end)

    # subscribe
    level_channel = _level_channel(level_instance)
    DungeonCrawlWeb.Endpoint.subscribe(level_channel)
    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    # should have nothing until after sending :perform_actions
    refute_receive %Phoenix.Socket.Broadcast{
      topic: ^level_channel}
    refute_receive %Phoenix.Socket.Broadcast{
      topic: ^player_channel}

    assert :ok = Process.send(instance_process, :perform_actions, [])

    refute_receive %Phoenix.Socket.Broadcast{
      topic: ^level_channel}
    assert_receive %Phoenix.Socket.Broadcast{
      topic: ^player_channel,
      event: "sound_effects",
      payload: %{sound_effects: [%{volume_modifier: 1, zzfx_params: ^expected_zzfx_params}]}}
  end

  test "perform_actions when reset when no players", %{instance_process: instance_process, level_instance: level_instance} do
    LevelProcess.run_with(instance_process, fn(state) ->
      {:ok, %{ state | count_to_idle: 0, state_values: Map.merge(state.state_values, %{reset_when_no_players: true}) }}
    end)

    ref = Process.monitor(instance_process)

    assert :ok = Process.send(instance_process, :perform_actions, [])

    # terminates the process, leaves the instance
    assert_receive {:DOWN, ^ref, :process, ^instance_process, :normal}
    assert DungeonCrawl.Repo.get Level, level_instance.id
  end

  test "check_on_inactive_players", %{instance_process: instance_process, level_instance: level_instance} do
    player_tile = DungeonInstances.create_tile!(
                    %{character: "@",
                      row: 1,
                      col: 3,
                      z_index: 0,
                      script: "",
                      state: "health: 10",
                      name: "player",
                      level_instance_id: level_instance.id})
    other_player_tile = DungeonInstances.create_tile!(
                          %{row: 1,
                            col: 3,
                            level_instance_id: level_instance.id})

    player_location = %Location{id: player_tile.id, tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    other_player_location = %Location{id: other_player_tile.id, tile_instance_id: other_player_tile.id, user_id_hash: "otherhash"}

    LevelProcess.run_with(instance_process, fn(state) ->
      {_, state} = Map.put(state, :inactive_players, %{player_tile.id => 5, other_player_tile.id => 0})
                   |> Levels.create_player_tile(player_tile, player_location)
      Levels.create_player_tile(state, other_player_tile, other_player_location)
    end)

    # old player is petrified
    :ok = Process.send(instance_process, :check_on_inactive_players, [])

    %Levels{ inactive_players: inactive_players,
             player_locations: player_locations } = LevelProcess.get_state(instance_process)

    assert %{other_player_tile.id => 1} == inactive_players
    assert player_locations == %{other_player_tile.id => other_player_location} # petrified and removed; this function tested elsewhere

    assert Scores.list_scores() == []

    # doesn't break when running on a player that isnt' there anymore
    LevelProcess.run_with(instance_process, fn(state) ->
      {:ok, Map.put(state, :inactive_players, %{player_tile.id => 5, other_player_tile.id => 0})}
    end)

    :ok = Process.send(instance_process, :check_on_inactive_players, [])

    %Levels{ inactive_players: inactive_players,
             player_locations: player_locations } = LevelProcess.get_state(instance_process)

    assert %{other_player_tile.id => 1} == inactive_players
    assert player_locations == %{other_player_tile.id => other_player_location} # petrified and removed; this function tested elsewhere
  end

  test "player_torch_timeout", %{instance_process: instance_process, level_instance: level_instance} do
    player_tile = DungeonInstances.create_tile!(
      %{character: "@",
        row: 1,
        col: 3,
        z_index: 1,
        state: "health: 10, torch_light: 6, light_range: 6, light_source: true",
        name: "player",
        level_instance_id: level_instance.id})
    other_player_tile = DungeonInstances.create_tile!(
      %{row: 1,
        col: 4,
        z_index: 1,
        state: "health: 10",
        level_instance_id: level_instance.id})
    dimmed_player_tile = DungeonInstances.create_tile!(
      %{row: 1,
        col: 5,
        z_index: 1,
        state: "health: 10, torch_light: 2, light_range: 6, light_source: true",
        level_instance_id: level_instance.id})
    out_player_tile = DungeonInstances.create_tile!(
      %{row: 1,
        col: 6,
        z_index: 1,
        state: "health: 10, torch_light: 1, light_range: 1, light_source: true",
        level_instance_id: level_instance.id})

    player_location = %Location{id: player_tile.id, tile_instance_id: player_tile.id, user_id_hash: "goodhash"}
    other_player_location = %Location{id: other_player_tile.id, tile_instance_id: other_player_tile.id, user_id_hash: "otherhash"}
    dimmed_player_location = %Location{id: dimmed_player_tile.id, tile_instance_id: dimmed_player_tile.id, user_id_hash: "outhash"}
    out_player_location = %Location{id: out_player_tile.id, tile_instance_id: out_player_tile.id, user_id_hash: "dimhash"}

    LevelProcess.run_with(instance_process, fn(state) ->
      {_, state} = Levels.create_player_tile(state, player_tile, player_location)
      {_, state} = Levels.create_player_tile(state, other_player_tile, other_player_location)
      {_, state} = Levels.create_player_tile(state, dimmed_player_tile, dimmed_player_location)
      Levels.create_player_tile(state, out_player_tile, out_player_location)
    end)

    # toches go out, dim, burn down, etc
    :ok = Process.send(instance_process, :player_torch_timeout, [])

    LevelProcess.run_with(instance_process, fn(state) ->
      assert %{light_source: true, light_range: 6, torch_light: 5} =
               Levels.get_tile_by_id(state, player_tile).parsed_state
      refute Levels.get_tile_by_id(state, other_player_location).parsed_state[:torch_light]
      assert %{light_source: true, light_range: 2, torch_light: 1} =
               Levels.get_tile_by_id(state, dimmed_player_location).parsed_state
      assert %{light_source: false, light_range: nil, torch_light: 0} =
               Levels.get_tile_by_id(state, out_player_tile).parsed_state

      {:ok, state}
    end)
  end

  test "write_db", %{instance_process: instance_process, level_instance: level_instance} do
    tt = insert_tile_template()

    tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white"},
        %{id: 123, character: "O", row: 1, col: 4, z_index: 0}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    new_tiles = [
        %{character: "N", row: 1, col: 5, z_index: 0, script: "#BECOME color: red"},
        %{character: "G", row: 1, col: 6, z_index: 0, script: "#BECOME color: gray"},
        %{character: "M", row: 1, col: 7, z_index: 0, script: "#BECOME color: red"},
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> {:ok, mt} = DungeonInstances.new_tile(mt); mt end)

    assert :ok = LevelProcess.load_level(instance_process, tiles ++ new_tiles)

    [tile_id_1, tile_id_2, tile_id_3] = tiles |> Enum.map(fn(mt) -> mt.id end)

    new_tile_1 = LevelProcess.get_tile(instance_process, 1, 5)
    new_tile_2 = LevelProcess.get_tile(instance_process, 1, 7)
    older_new_tile = LevelProcess.get_tile(instance_process, 1, 6)

    LevelProcess.run_with(instance_process, fn (instance_state) ->
      {:ok, %{ instance_state | new_ids: %{instance_state.new_ids | older_new_tile.id => 2 }}}
    end)

    assert :ok = LevelProcess.update_tile(instance_process, tile_id_1, %{character: "Y", row: 2, col: 3})
    assert :ok = LevelProcess.delete_tile(instance_process, tile_id_2)
    assert :ok = LevelProcess.delete_tile(instance_process, new_tile_1.id)

    Process.monitor(instance_process)
    assert :ok = Process.send(instance_process, :write_db, [])
    :timer.sleep 10 # let the process do its thing
    refute_receive _
    assert "Y" == Repo.get(Tile, tile_id_1).character
    refute Repo.get(Tile, tile_id_2)
    assert "O" == Repo.get(Tile, tile_id_3).character

    # new tiles younger than 2 write_db iterations don't get persisted to the DB yet
    assert new_tile_2 == LevelProcess.get_tile(instance_process, 1, 7)
    assert is_binary(new_tile_2.id)
    persisted_older_new_tile = LevelProcess.get_tile(instance_process, 1, 6)
    # new tiles that live past 2 or more write_db iterations get persisted to the DB
    assert is_integer(persisted_older_new_tile.id)
    assert "G" == Repo.get(Tile, persisted_older_new_tile.id).character
  end

  test "write_db stops the instance when the backing record is gone", %{instance_process: instance_process,
                                                                        level_instance: level_instance} do
    DungeonInstances.delete_level(level_instance)

    ref = Process.monitor(instance_process)
    assert :ok = Process.send(instance_process, :write_db, [])

    assert_receive {:DOWN, ^ref, :process, ^instance_process, :normal}
  end

  test "get_tile/2 gets a tile by its id", %{instance_process: instance_process, tile_id: tile_id} do
    assert %Tile{id: ^tile_id, character: "O", row: 1, col: 1, z_index: 0} = LevelProcess.get_tile(instance_process, tile_id)
  end

  test "get_tile/3 gets the top tile for the row, col coordinate", %{instance_process: instance_process, tile_id: tile_id} do
    assert %Tile{id: ^tile_id, character: "O", row: 1, col: 1, z_index: 0} = LevelProcess.get_tile(instance_process, 1, 1)
  end

  test "get_tile/3 gets nil if no tiles at the given coordinates", %{instance_process: instance_process} do
    refute LevelProcess.get_tile(instance_process, -1, -1)
  end

  test "get_tile/4 gets the top tile in the direction from the row, col coordinate", %{instance_process: instance_process, tile_id: tile_id} do
    assert %Tile{id: ^tile_id, character: "O", row: 1, col: 1, z_index: 0} = LevelProcess.get_tile(instance_process, 1, 1, "here")
  end

# get tiles

  test "get_tiles/3 gets the top tile for the row, col coordinate", %{instance_process: instance_process, tile_id: tile_id} do
    assert [tile] = LevelProcess.get_tiles(instance_process, 1, 1)
    assert %Tile{id: ^tile_id, character: "O", row: 1, col: 1, z_index: 0} = tile
  end

  test "get_tiles/3 gets emtpy array if no tiles at the given coordinates", %{instance_process: instance_process} do
    assert [] == LevelProcess.get_tiles(instance_process, -1, -1)
  end

  test "get_tiles/4 gets the top tile in the direction from the row, col coordinate", %{instance_process: instance_process, tile_id: tile_id} do
    assert [tile] = LevelProcess.get_tiles(instance_process, 1, 1, "here")
    assert %Tile{id: ^tile_id, character: "O", row: 1, col: 1, z_index: 0} = tile
  end
# end get tiles

  test "update_tile/3", %{instance_process: instance_process, tile_id: tile_id} do
    assert :ok = LevelProcess.update_tile(instance_process, tile_id, %{id: 11111, character: "X", row: 1, col: 1})
    assert %Tile{id: ^tile_id, character: "X", row: 1, col: 1, level_instance_id: m_id} = LevelProcess.get_tile(instance_process, tile_id)

    # Move to an empty space
    assert :ok = LevelProcess.update_tile(instance_process, tile_id, %{character: "Y", row: 2, col: 3})
    assert %Tile{id: ^tile_id, character: "Y", row: 2, col: 3} = LevelProcess.get_tile(instance_process, tile_id)

    # Move ontop of another tile
    another_tile = %Tile{id: -3, character: "O", row: 5, col: 6, z_index: 0, level_instance_id: m_id}
    LevelProcess.load_level(instance_process, [another_tile])

    # Won't move to the same z_index
    assert :ok = LevelProcess.update_tile(instance_process, tile_id, %{row: 5, col: 6})
    assert %Tile{id: ^tile_id, character: "Y", row: 2, col: 3, z_index: 0} = LevelProcess.get_tile(instance_process, tile_id)
    assert :ok = LevelProcess.update_tile(instance_process, tile_id, %{row: 5, col: 6, z_index: 1})
    assert %Tile{id: ^tile_id, character: "Y", row: 5, col: 6, z_index: 1} = LevelProcess.get_tile(instance_process, tile_id)
    assert %Tile{id: -3, character: "O", row: 5, col: 6, z_index: 0} = LevelProcess.get_tile(instance_process, another_tile.id)
  end

  test "delete_tile/2", %{instance_process: instance_process, tile_id: tile_id} do
    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord } = LevelProcess.get_state(instance_process)
    assert programs[tile_id]
    assert by_id[tile_id]
    assert %{ {1, 1} => %{ 0 => ^tile_id} } = by_coord

    assert :ok = LevelProcess.delete_tile(instance_process, tile_id)
    refute LevelProcess.get_tile(instance_process, tile_id)
    %Levels{ program_contexts: programs,
             map_by_ids: by_id,
             map_by_coords: by_coord } = LevelProcess.get_state(instance_process)
    refute programs[tile_id]
    refute by_id[tile_id]
    assert %{ {1, 1} => %{} } = by_coord
  end

  test "gameover/3", %{instance_process: instance_process, level_instance: level_instance} do
    {:module, levels_mock_mod, _, _} = LevelsMockFactory.generate(self(), DungeonCrawl.Gameover3.InstanceMock)

    tiles = [
        %{character: "B", row: 1, col: 2, z_index: 0, state: "damage: 5", name: "damager"},
        %{character: "O", row: 1, col: 4, z_index: 0, state: "health: 10, points: 9", name: "a nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, state: "damage: 10", name: "player"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{level_instance_id: level_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_tile!(mt) end)

    player_tile_1 = Enum.at(tiles, 0)
    player_tile_2 = Enum.at(tiles, 2)

    player_location_1 = %Location{id: 555, tile_instance_id: player_tile_1.id}
    player_location_2 = %Location{id: 556, tile_instance_id: player_tile_2.id}

    LevelProcess.run_with(instance_process, fn(state) ->
      {_, state} = Levels.create_player_tile(state, player_tile_1, player_location_1)
      Levels.create_player_tile(state, player_tile_2, player_location_2)
    end)

    %Levels{ instance_id: instance_id } = LevelProcess.get_state(instance_process)

    LevelProcess.gameover(instance_process, false, "loss", levels_mock_mod)

    assert_receive {:gameover_test, ^instance_id, false, "loss"}

    # cleanup
    :code.purge levels_mock_mod
    :code.delete levels_mock_mod
  end

  test "run_with/2", %{instance_process: instance_process, tile_id: tile_id} do
    new_tile = %Tile{id: 999, row: 1, col: 1, z_index: 1, character: "K"}
    return_value = LevelProcess.run_with(instance_process, fn (state) ->
                     Levels.create_tile(state, new_tile)
                   end)
    assert return_value == Map.put(new_tile, :parsed_state, %{})
    %Levels{ program_contexts: _programs,
             map_by_ids: _by_id,
             map_by_coords: by_coord } = LevelProcess.get_state(instance_process)
    assert %{ {1, 1} => %{ 0 => ^tile_id, 1 => 999} } = by_coord
  end

  defp _level_channel(level_instance) do
    "level:#{level_instance.dungeon_instance_id}:#{level_instance.number}:#{level_instance.player_location_id}"
  end
end

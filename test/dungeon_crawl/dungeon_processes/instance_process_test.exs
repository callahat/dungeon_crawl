defmodule DungeonCrawl.InstanceProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Player.Location

  # A lot of these tests are semi redundant, as the code that actually modifies the state lives
  # in the Instances module. Testing this also effectively hits the Instances code,
  # which also has its own set of similar tests.

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])
    tt = insert_tile_template()
    map_instance = insert_stubbed_dungeon_instance(
                     %{},
                     [%MapTile{character: "O", row: 1, col: 1, z_index: 0, script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#TERMINATE", tile_template_id: tt.id}])
    map_tile = DungeonCrawl.Repo.get_by(MapTile, %{map_instance_id: map_instance.id})

    InstanceProcess.set_instance_id(instance_process, map_instance.id)
    InstanceProcess.load_map(instance_process, [map_tile])

    %{instance_process: instance_process, map_tile_id: map_tile.id, map_instance: map_instance}
  end

  test "set_instance_id" do
    {:ok, instance_process} = InstanceProcess.start_link([])
    map_instance = insert_stubbed_dungeon_instance()
    map_instance_id = map_instance.id
    InstanceProcess.set_instance_id(instance_process, map_instance_id)
    assert %{ instance_id: ^map_instance_id } = InstanceProcess.get_state(instance_process)
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

  test "send_event", %{instance_process: instance_process, map_tile_id: map_tile_id} do
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
    dungeon_channel = "dungeons:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    tt = insert_tile_template()

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SHOOT east"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white\n#SEND touch, all"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "#TERMINATE"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
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
    bullet_tile_id = InstanceProcess.get_tile(instance_process, 1, 3).id

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
            payload: %{tiles: [%{row: 1, col: 2, rendering: "<div style='color: red'>O</div>"}]}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 3, rendering: "<div>M</div>"}]}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 3, rendering: "<div style='color: white'>M</div>"}]}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 3, rendering: "<div>◦</div>"}]}}
    # These were either idle or had no script
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 1}]}}
  end

  test "perform_actions adds messages to programs", %{instance_process: instance_process,
                                                      map_instance: map_instance,
                                                      map_tile_id: map_tile_id} do
    dungeon_channel = "dungeons:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    tt = insert_tile_template()

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white\n#SEND touch, all"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: ""}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)
    assert :ok = Process.send(instance_process, :perform_actions, [])

    %Instances{ program_contexts: program_contexts ,
                program_messages: program_messages } = InstanceProcess.get_state(instance_process)
    assert [] == program_messages # should be cleared after punting the messages to the actual progams

    # The last map tile in this setup has no active program
    expected = %{ map_tile_id => {"touch", %{map_tile_id: Enum.at(map_tiles,1).id}},
                  Enum.at(map_tiles,0).id => {"touch", %{map_tile_id: Enum.at(map_tiles,1).id}},
                  Enum.at(map_tiles,1).id => {"touch", %{map_tile_id: Enum.at(map_tiles,1).id}} }

    actual = program_contexts
             |> Map.to_list
             |> Enum.map(fn {id, context} -> {id, context.program.message} end)
             |> Enum.into(%{})

    assert actual == expected
  end

  test "perform_actions handles behavior 'destroyable'", %{instance_process: instance_process,
                                                           map_instance: map_instance,
                                                           map_tile_id: map_tile_id} do
    dungeon_channel = "dungeons:#{map_instance.id}"
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

    %Instances{ program_contexts: program_contexts,
                map_by_ids: map_by_ids,
                dirty_ids: dirty_ids } = InstanceProcess.get_state(instance_process)

    assert [ ^shooter_map_tile_id ] = Map.keys(program_contexts)
    assert [ ^shooter_map_tile_id ] = Map.keys(map_by_ids)
    assert %{ ^map_tile_id => :deleted, ^non_prog_tile_id => :deleted} = dirty_ids
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

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    [map_tile_id_1, map_tile_id_2, map_tile_id_3] = map_tiles |> Enum.map(fn(mt) -> mt.id end)

    assert :ok = InstanceProcess.update_tile(instance_process, map_tile_id_1, %{character: "Y", row: 2, col: 3})
    assert :ok = InstanceProcess.delete_tile(instance_process, map_tile_id_2)

    assert :ok = Process.send(instance_process, :write_db, [])
    :timer.sleep 10 # let the process do its thing
    assert "Y" == Repo.get(MapTile, map_tile_id_1).character
    refute Repo.get(MapTile, map_tile_id_2)
    assert "O" == Repo.get(MapTile, map_tile_id_3).character
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

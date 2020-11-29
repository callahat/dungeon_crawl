defmodule DungeonCrawl.InstanceProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.ProgramRegistry
  alias DungeonCrawl.DungeonProcesses.ProgramProcess
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
    InstanceProcess.set_state_values(instance_process, %{rows: 20, cols: 20})

    %{instance_process: instance_process, map_tile_id: map_tile.id, map_instance: map_instance}
  end

  test "it starts up its own ProgramRegistry" do
    {:ok, instance_process} = InstanceProcess.start_link([])

    assert %{ program_registry: program_registry } = InstanceProcess.get_state(instance_process)
    assert is_pid(program_registry)
    assert %ProgramRegistry{ instance_process: ^instance_process,
                             program_supervisor: program_supervisor } = ProgramRegistry.get_state(program_registry)

    assert is_pid(program_supervisor)
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
    map_instance = insert_stubbed_dungeon_instance()
    number = map_instance.number
    InstanceProcess.set_adjacent_map_id(instance_process, number, "west")
    assert %{ adjacent_map_ids: %{"west" => ^number} } = InstanceProcess.get_state(instance_process)
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
    assert %Instances{ map_by_ids: by_id,
                       map_by_coords: by_coord,
                       program_registry: program_registry } = InstanceProcess.get_state(instance_process)

    %{program: program_a, map_tile_id: ^map_tile_id} = ProgramRegistry.lookup(program_registry, map_tile_id)
                                                       |> ProgramProcess.get_state()
    %{program: program_b, map_tile_id: 236} = ProgramRegistry.lookup(program_registry, 236)
                                              |> ProgramProcess.get_state()

    assert %Program{status: :alive, instructions: program_a_instructions} = program_a
    assert %Program{status: :alive} = program_b

    # Does not update the tile nor load a program overtop if that tile already exists
    assert :ok = InstanceProcess.load_map(instance_process, [%MapTile{id: map_tile_id, character: "P", script: "#DIE"}])
    assert %Instances{ map_by_ids: ^by_id,
                       map_by_coords: ^by_coord,
                       instance_id: _ } = InstanceProcess.get_state(instance_process)
    %{program: program_a, map_tile_id: ^map_tile_id} = ProgramRegistry.lookup(program_registry, map_tile_id)
                                                       |> ProgramProcess.get_state()
    assert program_a.instructions == program_a_instructions
  end

  test "load_spawn_coordinates", %{instance_process: instance_process} do
    assert :ok = InstanceProcess.load_spawn_coordinates(instance_process, [{1,1}, {2,3}, {4,5}])
    assert %Instances{ spawn_coordinates: spawn_coordinates } = InstanceProcess.get_state(instance_process)
    assert Enum.sort([{1,1}, {2,3}, {4,5}]) == Enum.sort(spawn_coordinates)
  end

  test "start_scheduler", %{instance_process: instance_process} do
    # Starts the scheduler that will run every xxx ms and render changes
    InstanceProcess.start_scheduler(instance_process)
  end

  test "responds_to_event?", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    :timer.sleep 5 # flakey test, looks like something wasnt done spinning up so the below was timing out
    assert InstanceProcess.responds_to_event?(instance_process, map_tile_id, "TOUCH")
    refute InstanceProcess.responds_to_event?(instance_process, map_tile_id, "SNIFF")
    refute InstanceProcess.responds_to_event?(instance_process, map_tile_id-1, "ANYTHING")
  end

  test "send_event", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    player_location = %Location{id: 555}

    player_channel = "players:#{player_location.id}"
    DungeonCrawlWeb.Endpoint.subscribe(player_channel)

    %Instances{ program_registry: program_registry } = InstanceProcess.get_state(instance_process)
    program_process = ProgramRegistry.lookup(program_registry, map_tile_id)

    %{program: program} = ProgramProcess.get_state(program_process)

    # noop if it tile doesnt have a program
    InstanceProcess.send_event(instance_process, 111, "TOUCH", player_location)

    # it does something
    InstanceProcess.send_event(instance_process, map_tile_id, "TOUCH", player_location)

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "Hey"}}
    %{program: updated_program} = ProgramProcess.get_state(program_process)
    refute program == updated_program

    # prunes the program if died during the run of the label
    InstanceProcess.send_event(instance_process, map_tile_id, "TERMINATE", player_location)
    prog_ref = Process.monitor(program_process)
    assert_receive {:DOWN, ^prog_ref, :process, ^program_process, :normal}
    refute ProgramRegistry.lookup(program_registry, map_tile_id)
  end

  test "perform_actions", %{instance_process: instance_process, map_instance: map_instance} do
    dungeon_channel = "dungeons:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    tt = insert_tile_template()

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red\n#SHOOT east"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white"},
        %{character: "K", row: 1, col: 4, z_index: 0, script: "#TERMINATE"}
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
    bullet_tile_id = Enum.at(InstanceProcess.get_tiles(instance_process, 1, 2), -1).id

    assert state = InstanceProcess.get_state(instance_process)
    # this should still be active
    assert %{status: :alive} = ProgramRegistry.lookup(state.program_registry, bullet_tile_id)
                               |> ProgramProcess.get_state()
                               |> Map.fetch!(:program)
    # these will be idle
    assert %{status: :idle} = ProgramRegistry.lookup(state.program_registry, shooter_tile_id)
                               |> ProgramProcess.get_state()
                               |> Map.fetch!(:program)
    assert %{status: :idle} = ProgramRegistry.lookup(state.program_registry, east_tile_id)
                               |> ProgramProcess.get_state()
                               |> Map.fetch!(:program)
    # This one is dead and removed from the contexts
    refute ProgramRegistry.lookup(state.program_registry, eastest_tile_id)

    # render with the bullet spawn
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{col: 1, rendering: "<div>O</div>", row: 1},
                               %{col: 2, rendering: "<div style='color: red'>O</div>", row: 1},
                               %{col: 3, rendering: "<div style='color: white'>M</div>", row: 1},
                               %{col: 4, rendering: "<div>K</div>", row: 1}]}}

    # render the bullet moved
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{col: 2, rendering: "<div style='color: red'>O</div>", row: 1},
                               %{col: 3, rendering: "<div>◦</div>", row: 1}]}}

    # These were either idle or had no script
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 1}]}}
  end

  test "perform_actions where messages send programs", %{instance_process: instance_process,
                                                         map_instance: map_instance} do
    dungeon_channel = "dungeons:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    map_tiles = [
        %{name: "a", character: "O", row: 1, col: 2, z_index: 0, script: "#END\n:TOUCH\n#BECOME character: A"},
        %{name: "b", character: "O", row: 1, col: 3, z_index: 0, script: "#SEND touch, all\n#END\n:TOUCH\n#BECOME character: B"},
        %{name: "c", character: "O", row: 1, col: 4, z_index: 0, script: "#END\n:TOUCH\n#BECOME character: C"}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)
    assert :ok = Process.send(instance_process, :perform_actions, [])

    # from the scripts responding to a touch event
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{col: 2, rendering: "<div>A</div>", row: 1},
                               %{col: 3, rendering: "<div>B</div>", row: 1},
                               %{col: 4, rendering: "<div>C</div>", row: 1}]}}
  end

  test "perform_actions handles dealing with health when a tile is damaged", %{instance_process: instance_process,
                                                                               map_instance: map_instance} do
    dungeon_channel = "dungeons:#{map_instance.id}"
    DungeonCrawlWeb.Endpoint.subscribe(dungeon_channel)

    map_tiles = [
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#SEND shot, a nonprog\n#SEND bombed, player", state: "damage: 5"},
        %{character: "O", row: 1, col: 4, z_index: 0, script: "", state: "health: 10", name: "a nonprog"},
        %{character: "@", row: 1, col: 3, z_index: 0, script: "", state: "health: 10", name: "player"}
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

    # Wounded tiles
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "stat_update",
            payload: %{stats: %{health: 5}}}

    %Instances{ map_by_ids: map_by_ids,
                dirty_ids: _dirty_ids } = InstanceProcess.get_state(instance_process)

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
            payload: %{tiles: [%{row: 1, col: 3, rendering: "<div>✝</div>"}]}}

    %Instances{ map_by_ids: map_by_ids,
                dirty_ids: dirty_ids } = InstanceProcess.get_state(instance_process)

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

    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 4, rendering: "<div> </div>"}]}}
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            event: "tile_changes",
            payload: %{tiles: [%{row: 1, col: 1, rendering: "<div> </div>"}]}}

    %Instances{ program_registry: program_registry,
                map_by_ids: map_by_ids,
                dirty_ids: dirty_ids } = InstanceProcess.get_state(instance_process)

    assert %{status: :idle} = ProgramRegistry.lookup(program_registry, shooter_map_tile_id)
                              |> ProgramProcess.get_state()
                              |> Map.fetch!(:program)

    assert [ ^shooter_map_tile_id ] = Map.keys(map_by_ids)
    assert %{ ^map_tile_id => :deleted, ^non_prog_tile_id => :deleted} = dirty_ids
  end

  test "perform actions when no players present", %{instance_process: instance_process} do
    %{count_to_idle: count_to_idle, program_registry: program_registry} = InstanceProcess.get_state(instance_process)
    assert :ok = Process.send(instance_process, :perform_actions, [])
    assert count_to_idle - 1 == InstanceProcess.get_state(instance_process).count_to_idle
    # after n no player cycles, the instance goes idle
    assert :ok = Process.send(instance_process, :perform_actions, [])
    assert :ok = Process.send(instance_process, :perform_actions, [])
    assert :ok = Process.send(instance_process, :perform_actions, [])
    assert :ok = Process.send(instance_process, :perform_actions, [])
    assert :ok = Process.send(instance_process, :perform_actions, [])
    assert 0 == InstanceProcess.get_state(instance_process).count_to_idle

    program_ids = ProgramRegistry.list_all_program_ids(program_registry)

    Enum.each(program_ids, fn program_id ->
      assert %{active: false, timer_ref: nil} = ProgramRegistry.lookup(program_registry, program_id)
                                                |> ProgramProcess.get_state()
    end)

    # when a player enters the instance, the instance wakes back up
    InstanceProcess.run_with(instance_process, fn(state) ->
      Instances.create_player_map_tile(state, %MapTile{id: "newguy", row: 5, col: 5}, %Location{})
    end)

    assert 0 < InstanceProcess.get_state(instance_process).count_to_idle
    Enum.each(program_ids, fn program_id ->
      assert %{active: true, timer_ref: ref} = ProgramRegistry.lookup(program_registry, program_id)
                                                |> ProgramProcess.get_state()
      assert ref
    end)
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

  describe "get_tile/2,3,4" do
    test "gets a tile by its id", %{instance_process: instance_process, map_tile_id: map_tile_id} do
      assert %MapTile{id: map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = InstanceProcess.get_tile(instance_process, map_tile_id)
    end

    test "gets the top tile for the coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
      assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = InstanceProcess.get_tile(instance_process, 1, 1)
    end

    test "gets nil if no tiles at the given coordinates", %{instance_process: instance_process} do
      refute InstanceProcess.get_tile(instance_process, -1, -1)
    end

    test "gets the top tile in the direction from the coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
      assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = InstanceProcess.get_tile(instance_process, 1, 1, "here")
    end
  end

  describe "get_tiles/3,4" do
    test "gets the top tile for the coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
      assert [map_tile] = InstanceProcess.get_tiles(instance_process, 1, 1)
      assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = map_tile
    end

    test "gets emtpy array if no tiles at the given coordinates", %{instance_process: instance_process} do
      assert [] == InstanceProcess.get_tiles(instance_process, -1, -1)
    end

    test "gets the top tile in the direction from the coordinate", %{instance_process: instance_process, map_tile_id: map_tile_id} do
      assert [map_tile] = InstanceProcess.get_tiles(instance_process, 1, 1, "here")
      assert %MapTile{id: ^map_tile_id, character: "O", row: 1, col: 1, z_index: 0} = map_tile
    end
  end

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
    %Instances{ program_registry: program_registry,
                map_by_ids: by_id,
                map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    assert program_process = ProgramRegistry.lookup(program_registry, map_tile_id)
    assert by_id[map_tile_id]
    assert %{ {1, 1} => %{ 0 => ^map_tile_id} } = by_coord

    prog_ref = Process.monitor(program_process)

    assert :ok = InstanceProcess.delete_tile(instance_process, map_tile_id)
    refute InstanceProcess.get_tile(instance_process, map_tile_id)
    %Instances{ map_by_ids: by_id,
                map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    assert_receive {:DOWN, ^prog_ref, :process, ^program_process, :normal}
    refute by_id[map_tile_id]
    assert %{ {1, 1} => %{} } = by_coord
  end

  test "run_with/2", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    new_tile = %MapTile{id: 999, row: 1, col: 1, z_index: 1, character: "K"}
    return_value = InstanceProcess.run_with(instance_process, fn (state) ->
                     Instances.create_map_tile(state, new_tile)
                   end)
    assert return_value == Map.put(new_tile, :parsed_state, %{})
    %Instances{ map_by_ids: _by_id,
                map_by_coords: by_coord } = InstanceProcess.get_state(instance_process)
    assert %{ {1, 1} => %{ 0 => ^map_tile_id, 1 => 999} } = by_coord
  end
end

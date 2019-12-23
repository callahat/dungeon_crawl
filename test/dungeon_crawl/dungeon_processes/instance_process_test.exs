defmodule DungeonCrawl.InstanceProcessTest do
  use DungeonCrawl.DataCase

  import ExUnit.CaptureLog

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
                     [%MapTile{character: "O", row: 1, col: 1, z_index: 0, script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#DIE", tile_template_id: tt.id}])
    map_tile = DungeonCrawl.Repo.get_by(MapTile, %{map_instance_id: map_instance.id})

    InstanceProcess.load_map(instance_process, [map_tile])

    %{instance_process: instance_process, map_tile_id: map_tile.id, map_instance: map_instance}
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
                       object: %MapTile{},
                       program: %Program{status: :alive}},
             236 => %{event_sender: nil,
                       object: map_tile_with_script,
                       program: %Program{status: :alive}}
            } = programs

    # Does not load a program overtop an already running program for that map_tile id
    assert :ok = InstanceProcess.load_map(instance_process, [%MapTile{id: map_tile_id, script: "#DIE"}])
    assert %Instances{ program_contexts: programs,
                       map_by_ids: by_id,
                       map_by_coords: by_coord } == InstanceProcess.get_state(instance_process)
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
                       object: %MapTile{},
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
        %{character: "O", row: 1, col: 2, z_index: 0, script: "#BECOME color: red"},
        %{character: "O", row: 1, col: 3, z_index: 0, script: "#BECOME character: M\n#BECOME color: white"},
        %{id: 123, character: "O", row: 1, col: 4, z_index: 0}
      ]
      |> Enum.map(fn(mt) -> Map.merge(mt, %{tile_template_id: tt.id, map_instance_id: map_instance.id}) end)
      |> Enum.map(fn(mt) -> DungeonInstances.create_map_tile!(mt) end)

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel}

    assert :ok = Process.send(instance_process, :perform_actions, [])

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
    # These were either idle or had no script
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 1}]}}
    refute_receive %Phoenix.Socket.Broadcast{
            topic: ^dungeon_channel,
            payload: %{tiles: [%{row: 1, col: 4}]}}
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
end

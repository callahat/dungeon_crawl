defmodule DungeonCrawl.InstanceProcessTest do
  use DungeonCrawl.DataCase

  import ExUnit.CaptureLog

  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Player.Location

  setup do
    {:ok, instance_process} = InstanceProcess.start_link([])
    tt = insert_tile_template()
    map_instance = insert_stubbed_dungeon_instance(
                     %{},
                     [%MapTile{character: "O", row: 1, col: 1, z_index: 0, script: "#END\n:TOUCH\nHey\n#END\n:TERMINATE\n#DIE", tile_template_id: tt.id}])
    map_tile = DungeonCrawl.Repo.get_by(MapTile, %{map_instance_id: map_instance.id})

    InstanceProcess.load_map(instance_process, [map_tile])

    %{instance_process: instance_process, map_tile_id: map_tile.id}
  end

  test "load_map", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    map_tile_with_script = %MapTile{id: 236, character: "O", row: 1, col: 1, z_index: 0, script: "#BECOME color: red"}
    map_tiles = [%MapTile{id: 123, character: "O", row: 1, col: 2, z_index: 0},
                 map_tile_with_script]

    assert :ok = InstanceProcess.load_map(instance_process, map_tiles)

    # Starts the program(s) for the tiles, no script nothing done for that tile.
    assert { programs } = InstanceProcess.inspect_state(instance_process)
    assert %{^map_tile_id => %{event_sender: nil,
                       object: %MapTile{},
                       program: %Program{status: :alive}},
             236 => %{event_sender: nil,
                       object: map_tile_with_script,
                       program: %Program{status: :alive}}
            } = programs

    # Does not load a program overtop an already running program for that map_tile id
    assert :ok = InstanceProcess.load_map(instance_process, [%MapTile{id: map_tile_id, script: "#DIE"}])
    assert { programs } == InstanceProcess.inspect_state(instance_process)

    # Does not load a corrupt script (edge case - corrupt script shouldnt even get into the DB, and logs a warning
    assert capture_log(fn ->
             assert :ok = InstanceProcess.load_map(instance_process, [%MapTile{id: 123, script: "#NOT_A_REAL_COMMAND"}])
           end) =~ ~r/Possible corrupt script for map tile instance:/
    assert { programs } == InstanceProcess.inspect_state(instance_process)
  end

  test "start_scheduler", %{instance_process: instance_process} do
    # Starts the scheduler that will run every xxx ms and run the next parts of all the programs
    InstanceProcess.start_scheduler(instance_process)
  end

  test "inspect_state returns a listing of running programs", %{instance_process: instance_process, map_tile_id: map_tile_id} do
    assert { programs } = InstanceProcess.inspect_state(instance_process)
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

    { %{^map_tile_id => %{program: program} } } = InstanceProcess.inspect_state(instance_process)

    # noop if it tile doesnt have a program
    InstanceProcess.send_event(instance_process, 111, "TOUCH", player_location)
    { %{^map_tile_id => %{program: same_program} } } = InstanceProcess.inspect_state(instance_process)
    assert program == same_program

    # it does something
    InstanceProcess.send_event(instance_process, map_tile_id, "TOUCH", player_location)
    { %{^map_tile_id => %{program: updated_program} } } = InstanceProcess.inspect_state(instance_process)
    refute program == updated_program
    assert_receive %Phoenix.Socket.Broadcast{
            topic: ^player_channel,
            event: "message",
            payload: %{message: "Hey"}}

    # prunes the program if died during the run of the label
    InstanceProcess.send_event(instance_process, map_tile_id, "TERMINATE", player_location)
    assert { %{} } = InstanceProcess.inspect_state(instance_process)
  end

#  test "send_events", %{instance_process: instance_process} do
#    Process.send(instance, :perform_actions)
#  end
end

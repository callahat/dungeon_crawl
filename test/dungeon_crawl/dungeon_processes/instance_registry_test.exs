defmodule DungeonCrawl.InstanceRegistryTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry,InstanceProcess,Instances}
  alias DungeonCrawl.Scripting.Program

  setup do
    instance_registry = start_supervised!(InstanceRegistry)
    %{instance_registry: instance_registry}
  end

  test "lookup", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()

    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)

    InstanceRegistry.create(instance_registry, instance.id)
    
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)
  end

  test "lookup_or_create", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    DungeonCrawl.Dungeon.set_spawn_locations(instance.map_id, [{1,1}])

    assert {:ok, instance_process} = InstanceRegistry.lookup_or_create(instance_registry, instance.id)
    # Finds the already existing one
    assert {:ok, instance_process} == InstanceRegistry.lookup_or_create(instance_registry, instance.id)
  end

  test "create/2", %{instance_registry: instance_registry} do
    button_tile = insert_tile_template(%{state: "blocking: true", script: "#END\n:TOUCH\n*PimPom*"})
    instance = insert_stubbed_dungeon_instance(%{state: "flag: false"},
      [Map.merge(%{row: 1, col: 2, tile_template_id: button_tile.id, z_index: 0},
                 Map.take(button_tile, [:character,:color,:background_color,:state,:script])),
       %{row: 9, col: 10, name: "Floor", tile_template_id: nil, z_index: 0, character: ".", color: nil, background_color: nil, state: "", script: ""}])

    location = insert_player_location(%{map_instance_id: instance.id, row: 1, user_id_hash: "itsmehash"})
    map_tile = Repo.get_by(DungeonCrawl.DungeonInstances.MapTile, %{map_instance_id: instance.id, row: 1, col: 2})

    assert :ok = InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    # the instance map is loaded
    assert %Instances{program_contexts: programs,
                      map_by_ids: map_by_ids,
                      state_values: state_values,
                      instance_id: instance_id,
                      player_locations: player_locations,
                      spawn_coordinates: spawn_coordinates} = InstanceProcess.get_state(instance_process)
    assert programs == %{map_tile.id => %{
                                           object_id: map_tile.id,
                                           program: %Program{broadcasts: [],
                                                             instructions: %{1 => [:halt, [""]],
                                                                             2 => [:noop, "TOUCH"],
                                                                             3 => [:text, ["*PimPom*"]]},
                                                             labels: %{"touch" => [[2, true]]},
                                                             locked: false,
                                                             pc: 1,
                                                             responses: [],
                                                             status: :alive,
                                                             wait_cycles: 0
                                                    },
                                          event_sender: nil
                                        }
                       }
    assert player_locations == %{location.map_tile_instance_id => location
                                }
    assert map_by_ids[map_tile.id] == Map.put(map_tile, :parsed_state, %{blocking: true})
    assert state_values == %{flag: false, cols: 20, rows: 20}
    assert spawn_coordinates == [{9, 10}]
    assert instance_id == instance.id
  end

  test "create/3/4", %{instance_registry: instance_registry} do
    map_tile = %{id: 999, map_instance_id: 12345, row: 1, col: 2, z_index: 0, character: "B", state: "", script: ""}

    dungeon_map_tiles = [map_tile]

    assert map_tile.map_instance_id == InstanceRegistry.create(instance_registry, map_tile.map_instance_id, dungeon_map_tiles, [], %{flag: false}, nil, nil)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, map_tile.map_instance_id)

    # the instance map is loaded
    assert %Instances{program_contexts: programs,
                      map_by_ids: by_ids,
                      map_by_coords: by_coords,
                      state_values: %{flag: false}} = InstanceProcess.get_state(instance_process)
    assert by_ids == %{map_tile.id => Map.put(map_tile, :parsed_state, %{})}
    assert by_coords ==  %{ {map_tile.row, map_tile.col} => %{map_tile.z_index => map_tile.id} }
    assert programs == %{}

    # if no instance_id is given, it gets an available id and returns it
    # if no state values are given, defaults to empty map
    assert instance_id = InstanceRegistry.create(instance_registry, nil, dungeon_map_tiles)
    refute instance_id == map_tile.map_instance_id
    assert {:ok, instance_process2} = InstanceRegistry.lookup(instance_registry, instance_id)
    assert %Instances{program_contexts: programs,
                      map_by_ids: by_ids,
                      map_by_coords: by_coords,
                      state_values: %{}} = InstanceProcess.get_state(instance_process2)
    assert by_ids == %{map_tile.id => Map.merge(map_tile, %{map_instance_id: instance_id, parsed_state: %{}})}
  end

  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    DungeonCrawl.DungeonInstances.delete_map!(instance)
    log = ExUnit.CaptureLog.capture_log(fn -> InstanceRegistry.create(instance_registry, instance.id); :timer.sleep 2 end)
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
    assert log =~ "Got a CREATE cast for #{instance.id} but its already been cleared"
   end

  test "remove", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    # seems to take a quick micro second for the cast to be done
    InstanceRegistry.remove(instance_registry, instance.id)
    :timer.sleep 1
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
  end

  test "removes instances on exit", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    GenServer.stop(instance_process)
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
  end

  test "removes instance on crash", %{instance_registry: instance_registry} do
    instance = insert_stubbed_dungeon_instance()
    InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    # Stop the bucket with a non-normal reason
    GenServer.stop(instance_process, :shutdown)
    assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
  end
end

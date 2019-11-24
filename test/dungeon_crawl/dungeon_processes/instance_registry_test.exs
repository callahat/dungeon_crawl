defmodule DungeonCrawl.InstanceRegistryTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry,InstanceProcess}
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

    assert {:ok, instance_process} = InstanceRegistry.lookup_or_create(instance_registry, instance.id)
    # Finds the already existing one
    assert {:ok, instance_process} == InstanceRegistry.lookup_or_create(instance_registry, instance.id)
  end

  test "create", %{instance_registry: instance_registry} do
    button_tile = insert_tile_template(%{state: "blocking: true", script: "#END\n:TOUCH\n*PimPom*"})
    instance = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 1, col: 2, tile_template_id: button_tile.id, z_index: 0},
                 Map.take(button_tile, [:character,:color,:background_color,:state,:script]))])

    map_tile = Repo.get_by(DungeonCrawl.DungeonInstances.MapTile, %{map_instance_id: instance.id, row: 1, col: 2})

    assert :ok = InstanceRegistry.create(instance_registry, instance.id)
    assert {:ok, instance_process} = InstanceRegistry.lookup(instance_registry, instance.id)

    # the instance map is loaded
    assert {programs} = InstanceProcess.inspect_state(instance_process)
    assert programs == %{map_tile.id => %{
                                           object: map_tile,
                                           program: %Program{broadcasts: [],
                                                             instructions: %{1 => [:halt, [""]],
                                                                             2 => [:noop, "TOUCH"],
                                                                             3 => [:text, ["*PimPom*"]]},
                                                             labels: %{"TOUCH" => [[2, true]]},
                                                             locked: false,
                                                             pc: 1,
                                                             responses: [],
                                                             status: :alive,
                                                             wait_cycles: 0
                                                    },
                                          event_sender: nil
                                        }
                       }
    # the scheduler should be started too. Not sure a good way to test this via this spec. It will be apparent though if
    # the scheduler
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

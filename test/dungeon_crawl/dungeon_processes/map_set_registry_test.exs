defmodule DungeonCrawl.MapSetRegistryTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.{Dungeon,Tile}
  alias DungeonCrawl.DungeonProcesses.{MapSetRegistry,MapSetProcess,InstanceRegistry}

  setup do
    map_set_registry = start_supervised!(MapSetRegistry)
    %{map_set_registry: map_set_registry}
  end

  test "lookup", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()

    assert :error = MapSetRegistry.lookup(map_set_registry, di.id)

    MapSetRegistry.create(map_set_registry, di.id)

    assert {:ok, _msi_process} = MapSetRegistry.lookup(map_set_registry, di.id)
  end

  test "lookup_or_create", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()

    assert {:ok, msi_process} = MapSetRegistry.lookup_or_create(map_set_registry, di.id)
    # Finds the already existing one
    assert {:ok, ^msi_process} = MapSetRegistry.lookup_or_create(map_set_registry, di.id)
  end

  test "create/2", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance(%{state: "flag: off"}, %{}, [[%Tile{character: "O", row: 1, col: 1, z_index: 0}]])
    d = Repo.preload(di, :dungeon).dungeon

    assert :ok = MapSetRegistry.create(map_set_registry, di.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, di.id)
    assert %MapSetProcess{dungeon: ^d,
                          dungeon_instance: %Dungeon{},
                          state_values: %{flag: "off"},
                          instance_registry: instance_registry,
                          entrances: []} = MapSetProcess.get_state(msi_process)
    level_id = Repo.preload(di, :levels).levels
               |> Enum.map(&(&1.id))
               |> Enum.at(0)
    assert instance_list = InstanceRegistry.list(instance_registry)
    assert map_size(instance_list) == 1
    assert %{^level_id => _} = instance_list
  end

  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    DungeonInstances.delete_dungeon(di)
    log = ExUnit.CaptureLog.capture_log(fn -> MapSetRegistry.create(map_set_registry, di.id); :timer.sleep 5 end)
    assert :error = MapSetRegistry.lookup(map_set_registry, di.id)
    assert log =~ "Got a CREATE cast for #{di.id} but its already been cleared"
   end

  test "remove", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    MapSetRegistry.create(map_set_registry, di.id)
    assert {:ok, _msi_process} = MapSetRegistry.lookup(map_set_registry, di.id)

    # seems to take a quick micro second for the cast to be done
    MapSetRegistry.remove(map_set_registry, di.id)
    :timer.sleep 1
    assert :error = MapSetRegistry.lookup(map_set_registry, di.id)
  end

  test "removes instances on exit", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    MapSetRegistry.create(map_set_registry, di.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, di.id)

    GenServer.stop(msi_process)
    assert :error = MapSetRegistry.lookup(map_set_registry, di.id)
  end

  test "removes instance on crash", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    MapSetRegistry.create(map_set_registry, di.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, di.id)

    # Stop the bucket with a non-normal reason
    GenServer.stop(msi_process, :shutdown)
    assert :error = MapSetRegistry.lookup(map_set_registry, di.id)
  end

  test "list", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    di_id = di.id
    MapSetRegistry.create(map_set_registry, di.id)

    assert di_ids = MapSetRegistry.list(map_set_registry)
    assert %{^di_id => _pid} = di_ids
    assert length(Map.keys(di_ids)) == 1
  end
end


defmodule DungeonCrawl.MapSetRegistryTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.{MapSet,MapTile}
  alias DungeonCrawl.DungeonProcesses.{MapSetRegistry,MapSetProcess,InstanceRegistry}

  setup do
    map_set_registry = start_supervised!(MapSetRegistry)
    %{map_set_registry: map_set_registry}
  end

  test "lookup", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()

    assert :error = MapSetRegistry.lookup(map_set_registry, msi.id)

    MapSetRegistry.create(map_set_registry, msi.id)

    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, msi.id)
  end

  test "lookup_or_create", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()

    assert {:ok, msi_process} = MapSetRegistry.lookup_or_create(map_set_registry, msi.id)
    # Finds the already existing one
    assert {:ok, ^msi_process} = MapSetRegistry.lookup_or_create(map_set_registry, msi.id)
  end

  test "create/2", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance(%{state: "flag: off"}, %{}, [[%MapTile{character: "O", row: 1, col: 1, z_index: 0}]])
    ms = Repo.preload(msi, :map_set).map_set

    assert :ok = MapSetRegistry.create(map_set_registry, msi.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, msi.id)
    assert %MapSetProcess{map_set: ^ms,
                          map_set_instance: %MapSet{},
                          state_values: %{flag: "off"},
                          instance_registry: instance_registry,
                          entrances: []} = MapSetProcess.get_state(msi_process)
    map_id = Repo.preload(msi, :maps).maps
             |> Enum.map(&(&1.id))
             |> Enum.at(0)
    assert instance_list = InstanceRegistry.list(instance_registry)
    assert map_size(instance_list) == 1
    assert %{^map_id => _} = instance_list
  end

  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()
    DungeonInstances.delete_map_set(msi)
    log = ExUnit.CaptureLog.capture_log(fn -> MapSetRegistry.create(map_set_registry, msi.id); :timer.sleep 5 end)
    assert :error = MapSetRegistry.lookup(map_set_registry, msi.id)
    assert log =~ "Got a CREATE cast for #{msi.id} but its already been cleared"
   end

  test "remove", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()
    MapSetRegistry.create(map_set_registry, msi.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, msi.id)

    # seems to take a quick micro second for the cast to be done
    MapSetRegistry.remove(map_set_registry, msi.id)
    :timer.sleep 1
    assert :error = MapSetRegistry.lookup(map_set_registry, msi.id)
  end

  test "removes instances on exit", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()
    MapSetRegistry.create(map_set_registry, msi.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, msi.id)

    GenServer.stop(msi_process)
    assert :error = MapSetRegistry.lookup(map_set_registry, msi.id)
  end

  test "removes instance on crash", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()
    MapSetRegistry.create(map_set_registry, msi.id)
    assert {:ok, msi_process} = MapSetRegistry.lookup(map_set_registry, msi.id)

    # Stop the bucket with a non-normal reason
    GenServer.stop(msi_process, :shutdown)
    assert :error = MapSetRegistry.lookup(map_set_registry, msi.id)
  end

  test "list", %{map_set_registry: map_set_registry} do
    msi = insert_stubbed_map_set_instance()
    msi_id = msi.id
    MapSetRegistry.create(map_set_registry, msi.id)

    assert msi_ids = MapSetRegistry.list(map_set_registry)
    assert %{^msi_id => _pid} = msi_ids
    assert length(Map.keys(msi_ids)) == 1
  end
end


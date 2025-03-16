defmodule DungeonCrawl.DungeonRegistryTest do
  use DungeonCrawl.DataCase
  use AssertEventually, timeout: 50, interval: 5

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.{Dungeon,Tile}
  alias DungeonCrawl.DungeonProcesses.{DungeonRegistry,DungeonProcess,LevelRegistry}
  alias DungeonCrawl.Horde.Registry

  setup do
    map_set_registry = start_supervised!(DungeonRegistry)
    %{map_set_registry: map_set_registry}
  end

  test "lookup", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()

    assert :error = DungeonRegistry.lookup(map_set_registry, di.id)

    DungeonRegistry.create(map_set_registry, di.id)

    assert {:ok, msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)

    # cleanup
    GenServer.stop(msi_process, :shutdown)
  end

  @tag capture_log: true
  test "lookup but dead PID in the registry logs message", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    DungeonRegistry.create(map_set_registry, di.id)
    {:ok, msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)
    GenServer.stop(msi_process, :shutdown)
    Registry.add_dungeon_process_meta(di.id, msi_process)

    log = ExUnit.CaptureLog.capture_log(fn ->
      assert :error = DungeonRegistry.lookup(map_set_registry, di.id)
      :timer.sleep 5
    end)
    assert log =~ ~r/warning.*?PID.*?appears to be dead for dungeon id #{di.id}; removing/

    # no cleanup needed; msi_process is already dead
  end

  test "lookup_or_create", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()

    assert {:ok, msi_process} = DungeonRegistry.lookup_or_create(map_set_registry, di.id)
    # Finds the already existing one
    assert {:ok, ^msi_process} = DungeonRegistry.lookup_or_create(map_set_registry, di.id)

    # cleanup
    GenServer.stop(msi_process, :shutdown)
  end

  @tag capture_log: true
  test "create/2", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance(%{state: %{"flag" => "off"}}, %{}, [[%Tile{character: "O", row: 1, col: 1, z_index: 0}]])
    d = Repo.preload(di, :dungeon).dungeon

    assert :ok = DungeonRegistry.create(map_set_registry, di.id)
    assert {:ok, msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)
    assert %DungeonProcess{dungeon: ^d,
                          dungeon_instance: %Dungeon{},
                          state_values: %{"flag" => "off"},
                          instance_registry: instance_registry,
                          entrances: []} = DungeonProcess.get_state(msi_process)
    {level_id, level_number} = Repo.preload(di, :levels).levels
                               |> Enum.map(&({&1.id, &1.number}))
                               |> Enum.at(0)
    assert instance_list = LevelRegistry.list(instance_registry)
    assert map_size(instance_list) == 1
    assert %{^level_number => %{nil => {^level_id, _}}} = instance_list

    # noop since it already was created
    assert :ok = DungeonRegistry.create(map_set_registry, di.id)
    assert {:ok, ^msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)

    # create with a killed process logs a message and creates
    GenServer.stop(msi_process, :shutdown)
    Registry.add_dungeon_process_meta(di.id, msi_process)
    log = ExUnit.CaptureLog.capture_log(fn ->
      assert :ok = DungeonRegistry.create(map_set_registry, di.id)
      :timer.sleep 5
    end)
    assert log =~ ~r/warning.*?PID.*?appears to be dead for dungeon id #{di.id}; removing/

    # no cleanup needed; msi_process is already dead
  end

  @tag capture_log: true
  test "create safely handles a dungeon instance that does not exist in the DB", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    DungeonInstances.delete_dungeon(di)
    log = ExUnit.CaptureLog.capture_log(fn -> DungeonRegistry.create(map_set_registry, di.id); :timer.sleep 5 end)
    assert :error = DungeonRegistry.lookup(map_set_registry, di.id)
    assert log =~ "Got a CREATE cast for #{di.id} but its already been cleared"
  end

  test "remove", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    DungeonRegistry.create(map_set_registry, di.id)
    assert {:ok, _msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)

    # seems to take a quick micro second for the cast to be done
    DungeonRegistry.remove(map_set_registry, di.id)
    eventually assert :error = DungeonRegistry.lookup(map_set_registry, di.id)

    # noop since its already removed, no error raised
    DungeonRegistry.remove(map_set_registry, di.id)
  end

  test "removes instances on exit", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    DungeonRegistry.create(map_set_registry, di.id)
    assert {:ok, msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)
    assert Process.alive?(msi_process)
    GenServer.stop(msi_process, :shutdown)
    refute Process.alive?(msi_process)
    assert :error = DungeonRegistry.lookup(map_set_registry, di.id)
  end

  test "removes instance on crash", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    DungeonRegistry.create(map_set_registry, di.id)
    assert {:ok, msi_process} = DungeonRegistry.lookup(map_set_registry, di.id)

    # Stop the bucket with a non-normal reason
    GenServer.stop(msi_process, :shutdown)
    assert :error = DungeonRegistry.lookup(map_set_registry, di.id)
  end

  test "list", %{map_set_registry: map_set_registry} do
    di = insert_stubbed_dungeon_instance()
    di_id = di.id
    DungeonRegistry.create(map_set_registry, di.id)

    assert di_ids = DungeonRegistry.list(map_set_registry)
    assert %{^di_id => pid} = di_ids

    # cleanup
    GenServer.stop(pid, :shutdown)
  end
end


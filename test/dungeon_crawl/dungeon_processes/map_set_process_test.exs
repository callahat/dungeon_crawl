defmodule DungeonCrawl.MapSetProcessTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.MapSetProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonInstances.MapTile

  # A lot of these tests are semi redundant, as the code that actually modifies the state lives
  # in the Instances module. Testing this also effectively hits the Instances code,
  # which also has its own set of similar tests.

  setup do
    {:ok, map_set_process} = MapSetProcess.start_link([])

    map_set_instance = insert_stubbed_map_set_instance(%{}, %{}, [[%MapTile{character: "O", row: 1, col: 1, z_index: 0}]])

    %{map_set_process: map_set_process, map_set_instance: map_set_instance}
  end

  test "set_map_set_instance", %{map_set_process: map_set_process, map_set_instance: map_set_instance} do
    MapSetProcess.set_map_set_instance(map_set_process, map_set_instance)
    assert %{ map_set_instance: ^map_set_instance } = MapSetProcess.get_state(map_set_process)
  end

  test "set_state_values", %{map_set_process: map_set_process} do
    assert :ok = MapSetProcess.set_state_values(map_set_process, %{foo: :bar, baz: :qux})
    assert %{state_values: %{foo: :bar, baz: :qux}} = MapSetProcess.get_state(map_set_process)
  end

  test "set_state_value", %{map_set_process: map_set_process} do
    assert :ok = MapSetProcess.set_state_value(map_set_process, :foo, :bar)
    assert %{state_values: %{foo: :bar}} = MapSetProcess.get_state(map_set_process)
  end

  test "get_state_value", %{map_set_process: map_set_process} do
    MapSetProcess.set_state_value(map_set_process, :foo, :bar)
    assert :bar = MapSetProcess.get_state_value(map_set_process, :foo)
    refute MapSetProcess.get_state_value(map_set_process, :bax)
  end

  test "get_instance_registry", %{map_set_process: map_set_process} do
    assert pid = MapSetProcess.get_instance_registry(map_set_process)
    assert %{} = InstanceRegistry.list(pid)
  end

  test "get_state", %{map_set_process: map_set_process} do
    assert %MapSetProcess{map_set_instance: _,
                          state_values: _,
                          instance_registry: _,
                          entrances: []} = MapSetProcess.get_state(map_set_process)
  end

  test "load_instance with an id", %{map_set_process: map_set_process, map_set_instance: map_set_instance} do
    [map_instance] = Repo.preload(map_set_instance, :maps).maps
    map_instance_id = map_instance.id
    assert :ok = MapSetProcess.load_instance(map_set_process, map_instance.id)
    assert %{^map_instance_id => _} = MapSetProcess.get_instance_registry(map_set_process)
                                      |> InstanceRegistry.list()
    assert %MapSetProcess{entrances: []} = MapSetProcess.get_state(map_set_process)
  end

  test "load_instance", %{map_set_process: map_set_process, map_set_instance: map_set_instance} do
    [map_instance] = Repo.preload(map_set_instance, :maps).maps
    map_instance_id = map_instance.id
    assert :ok = MapSetProcess.load_instance(map_set_process, map_instance)
    assert %{^map_instance_id => _} = MapSetProcess.get_instance_registry(map_set_process)
                                      |> InstanceRegistry.list()
    assert %MapSetProcess{entrances: []} = MapSetProcess.get_state(map_set_process)
  end

  test "load_instance that's an entrance", %{map_set_process: map_set_process, map_set_instance: map_set_instance} do
    [map_instance] = Repo.preload(map_set_instance, :maps).maps
    map_instance_id = map_instance.id
    assert :ok = MapSetProcess.load_instance(map_set_process, %{ map_instance | entrance: true })
    assert %MapSetProcess{entrances: [^map_instance_id]} = MapSetProcess.get_state(map_set_process)
  end
end
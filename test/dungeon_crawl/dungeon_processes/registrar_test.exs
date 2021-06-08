defmodule DungeonCrawl.RegistrarTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry

  setup do
    map_set_registry = start_supervised!(DungeonRegistry)
    instance = insert_stubbed_level_instance()

    DungeonRegistry.create(map_set_registry, instance.dungeon_instance_id)

    %{di_id: instance.dungeon_instance_id, instance_id: instance.id}
  end

  test "instance_process/2", %{di_id: di_id, instance_id: instance_id} do
    refute Registrar.instance_process(0, instance_id)
    assert Registrar.instance_process(di_id, instance_id)
    refute Registrar.instance_process(di_id, 0)
  end

  test "instance_registry/1", %{di_id: di_id} do
    refute Registrar.instance_registry(0)
    assert Registrar.instance_registry(di_id)
  end
end


defmodule DungeonCrawl.MapSetsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.MapSets
  alias DungeonCrawl.DungeonProcesses.MapSetRegistry

  setup do
    map_set_registry = start_supervised!(MapSetRegistry)
    instance = insert_stubbed_dungeon_instance()

    MapSetRegistry.create(map_set_registry, instance.map_set_instance_id)

    %{msi_id: instance.map_set_instance_id, instance_id: instance.id}
  end

  test "instance_process/2", %{msi_id: msi_id, instance_id: instance_id} do
    refute MapSets.instance_process(0, instance_id)
    assert MapSets.instance_process(msi_id, instance_id)
    refute MapSets.instance_process(msi_id, 0)
  end

  test "instance_registry/1", %{msi_id: msi_id} do
    refute MapSets.instance_registry(0)
    assert MapSets.instance_registry(msi_id)
  end
end


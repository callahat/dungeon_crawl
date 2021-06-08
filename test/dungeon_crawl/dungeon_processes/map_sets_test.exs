defmodule DungeonCrawl.MapSetsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.MapSets
  alias DungeonCrawl.DungeonProcesses.MapSetRegistry

  setup do
    map_set_registry = start_supervised!(MapSetRegistry)
    instance = insert_stubbed_level_instance()

    MapSetRegistry.create(map_set_registry, instance.dungeon_instance_id)

    %{di_id: instance.dungeon_instance_id, instance_id: instance.id}
  end

  test "instance_process/2", %{di_id: di_id, instance_id: instance_id} do
    refute MapSets.instance_process(0, instance_id)
    assert MapSets.instance_process(di_id, instance_id)
    refute MapSets.instance_process(di_id, 0)
  end

  test "instance_registry/1", %{di_id: di_id} do
    refute MapSets.instance_registry(0)
    assert MapSets.instance_registry(di_id)
  end
end


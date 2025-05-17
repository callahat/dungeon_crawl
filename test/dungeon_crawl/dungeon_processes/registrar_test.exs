defmodule DungeonCrawl.RegistrarTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry

  setup do
    instance = insert_stubbed_level_instance()

    DungeonRegistry.create(DungeonInstanceRegistry, instance.dungeon_instance_id)

    %{di_id: instance.dungeon_instance_id, level_number: instance.number}
  end

  test "instance_process/1", %{di_id: di_id, level_number: level_number} do
    refute Registrar.instance_process(%{dungeon_instance_id: 0, number: level_number, player_location_id: nil})
    assert {:ok, _pid} = Registrar.instance_process(%{dungeon_instance_id: di_id, number: level_number, player_location_id: nil})
    # because its an universal instance same pid regardless of the locaion_id given
    assert Registrar.instance_process(%{dungeon_instance_id: di_id, number: level_number, player_location_id: nil}) ==
             Registrar.instance_process(%{dungeon_instance_id: di_id, number: level_number, player_location_id: 1})
    refute Registrar.instance_process(%{dungeon_instance_id: di_id, number: 0, player_location_id: nil})
  end

  test "instance_process/3", %{di_id: di_id, level_number: level_number} do
    refute Registrar.instance_process(0, level_number, nil)
    assert {:ok, _pid} = Registrar.instance_process(di_id, level_number, nil)
    # because its an universal instance same pid regardless of the locaion_id given
    assert Registrar.instance_process(di_id, level_number, nil) ==
             Registrar.instance_process(di_id, level_number, 1)
    refute Registrar.instance_process(di_id, 0, nil)
  end

  test "instance_registry/1", %{di_id: di_id} do
    refute Registrar.instance_registry(0)
    assert {:ok, _pid} = Registrar.instance_registry(di_id)
  end
end


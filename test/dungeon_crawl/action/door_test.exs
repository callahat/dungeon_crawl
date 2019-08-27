defmodule DungeonCrawl.Action.DoorTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Action.Door
  alias DungeonCrawl.DungeonInstances, as: Dungeon
  alias DungeonCrawl.DungeonInstances.MapTile

  test "open/1 opens a closed door" do
    {_open_door, closed_door} = insert_openable_closable_tile_template_pair()

    dungeon = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 1, col: 1, tile_template_id: closed_door.id, z_index: 0},Map.take(closed_door, [:character,:color,:background_color,:state]))])
    target_door = Dungeon.get_map_tile!(%{map_instance_id: dungeon.id, row: 1, col: 1})

    assert {:ok, %{door_location: %{row: 1, col: 1, map_tile: open_door}}} = Door.open(target_door)
    assert Repo.get_by(MapTile, %{id: open_door.id, row: 1, col: 1, tile_template_id: open_door.tile_template_id})
  end

  test "open/1 is invalid for anything other than a closed door" do
    real_fake_door = insert_tile_template(%{character: "H", responders: "{}"})

    dungeon = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 4, col: 5, tile_template_id: real_fake_door.id, z_index: 0}, Map.take(real_fake_door, [:character,:color,:background_color,:state]))])
    target_door = Dungeon.get_map_tile!(%{map_instance_id: dungeon.id, row: 4, col: 5})

    assert {:invalid} = Door.open(target_door)
    assert Repo.get_by(MapTile, %{row: 4, col: 5, tile_template_id: real_fake_door.id})
  end

  test "close/1 closes an open door" do
    {open_door, _closed_door} = insert_openable_closable_tile_template_pair()

    dungeon = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 2, col: 3, tile_template_id: open_door.id, z_index: 0}, Map.take(open_door, [:character,:color,:background_color,:state]))])
    target_door = Dungeon.get_map_tile!(%{map_instance_id: dungeon.id, row: 2, col: 3})

    assert {:ok, %{door_location: %{row: 2, col: 3, map_tile: closed_door}}} = Door.close(target_door)
    assert Repo.get_by(MapTile, %{id: closed_door.id, row: 2, col: 3, tile_template_id: closed_door.tile_template_id})
  end

  test "close/1 is invalid for anything other than an open door" do
    real_fake_door = insert_tile_template(%{character: "H", responders: "{}"})

    dungeon = insert_stubbed_dungeon_instance(%{},
      [Map.merge(%{row: 8, col: 9, tile_template_id: real_fake_door.id, z_index: 0}, Map.take(real_fake_door, [:character,:color,:background_color,:state]))])
    target_door = Dungeon.get_map_tile!(%{map_instance_id: dungeon.id, row: 8, col: 9})

    assert {:invalid} = Door.close(target_door)
    assert Repo.get_by(MapTile, %{row: 8, col: 9, tile_template_id: real_fake_door.id})
  end
end


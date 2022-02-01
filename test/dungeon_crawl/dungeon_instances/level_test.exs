defmodule DungeonCrawl.DungeonInstances.LevelTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Repo
  alias DungeonCrawl.DungeonInstances.Level
  alias DungeonCrawl.Player.Location

  test "on_delete deletes all associated player_locations" do
    level_instance = insert_autogenerated_level_instance()
    player_loc = insert_player_location(%{level_instance_id: level_instance.id})
    assert Repo.preload(level_instance, :locations).locations != []
    assert Repo.delete(level_instance)
    refute Repo.get_by(Location, %{user_id_hash: player_loc.user_id_hash})
    assert Repo.preload(level_instance, :locations).locations == []
  end

  test "level_instance number must be unique for dungeon and owner" do
    level_instance = insert_autogenerated_level_instance()
    changeset = Level.changeset(
                  %Level{player_location_id: nil},
                  Map.take(level_instance, [:number, :name, :level_id, :dungeon_instance_id, :height, :width])
                )

    assert {:error, %{errors: [number: {"Level Number already exists", _}]}} = Repo.insert(changeset)

    # level instance that is owned by a player
    other_player = insert_player_location(%{level_instance_id: level_instance.id})
    changeset = Level.changeset(
      %Level{},
      Map.take(level_instance, [:number, :name, :level_id, :dungeon_instance_id, :height, :width])
      |> Map.merge(%{player_location_id: other_player.id})
    )

    assert {:ok, _level} = Repo.insert(changeset)

    assert {:error, %{errors: [number: {"Level Number already exists", _}]}} = Repo.insert(changeset)
  end
end

defmodule DungeonCrawl.DungeonInstances.DungeonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances.Dungeon
  alias DungeonCrawl.Player.Location

  test "on_delete deletes all associated player_locations" do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    player_loc = insert_player_location(%{level_instance_id: instance.id})
    assert Repo.preload(instance, :locations).locations != []
    assert Repo.delete(dungeon_instance)
    refute Repo.get_by(Location, %{user_id_hash: player_loc.user_id_hash})
    assert Repo.preload(instance, :locations).locations == []
  end

  test "valid changeset populates passcode" do
    changeset = Dungeon.changeset(%Dungeon{}, %{name: "test", dungeon_id: 1})
    assert changeset.changes.passcode =~ ~r/^\w{8}$/
  end
end

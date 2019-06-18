defmodule DungeonCrawl.Dungeon.MapTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player.Location

  test "on_delete deletes all associated player_locations" do
    dungeon = insert_autogenerated_dungeon()
    player_loc = insert_player_location(%{dungeon_id: dungeon.id})
    assert {:ok, _dungeon} = DungeonCrawl.Dungeon.delete_map(dungeon)
    refute Repo.get_by(Location, %{user_id_hash: player_loc.user_id_hash})
  end
end

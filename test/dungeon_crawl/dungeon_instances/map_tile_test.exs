defmodule DungeonCrawl.DungeonInstances.MapTileTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.MapTile

  @valid_attrs %{row: 42, col: 42, z_index: 1, tile_template_id: 2, map_instance_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = MapTile.changeset(%MapTile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = MapTile.changeset(%MapTile{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "on_delete deletes all associated player_locations" do
    instance = insert_autogenerated_dungeon_instance()
    player_loc = Repo.preload insert_player_location(%{map_instance_id: instance.id}), :map_tile
    assert {:ok, deleted_player_tile} = Repo.delete(player_loc.map_tile)
    refute Repo.get_by(Location, %{user_id_hash: player_loc.user_id_hash})
    refute Repo.get(MapTile, deleted_player_tile.id)
  end
end

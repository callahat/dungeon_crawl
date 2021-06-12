defmodule DungeonCrawl.Player.LocationTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player.Location

  @valid_attrs %{user_id_hash: "some content", tile_instance_id: 1}
  @invalid_attrs Map.merge(@valid_attrs, %{tile_instance_id: nil})

  test "changeset with valid attributes" do
    changeset = Location.changeset(%Location{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Location.changeset(%Location{}, @invalid_attrs)
    refute changeset.valid?
  end
end


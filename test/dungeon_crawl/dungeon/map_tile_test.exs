defmodule DungeonCrawl.Dungeon.MapTileTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon.MapTile

  @valid_attrs %{tile: "!", row: 42, col: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = MapTile.changeset(%MapTile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = MapTile.changeset(%MapTile{}, @invalid_attrs)
    refute changeset.valid?
  end
end

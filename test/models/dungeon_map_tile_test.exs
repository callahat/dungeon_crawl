defmodule DungeonCrawlWeb.DungeonMapTileTest do
  use DungeonCrawlWeb.ModelCase

  alias DungeonCrawlWeb.DungeonMapTile

  @valid_attrs %{tile: "!", row: 42, col: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = DungeonMapTile.changeset(%DungeonMapTile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = DungeonMapTile.changeset(%DungeonMapTile{}, @invalid_attrs)
    refute changeset.valid?
  end
end

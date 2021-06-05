defmodule DungeonCrawl.Dungeons.MapTileTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons.MapTile

  @valid_attrs %{row: 42, col: 42, tile_template_id: 2, dungeon_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = MapTile.changeset(%MapTile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = MapTile.changeset(%MapTile{}, Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = MapTile.changeset(%MapTile{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = MapTile.changeset(%MapTile{}, Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end
end

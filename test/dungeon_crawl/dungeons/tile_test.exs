defmodule DungeonCrawl.Dungeons.TileTest do
  use DungeonCrawl.DataCase

  require DungeonCrawl.SharedTests

  alias DungeonCrawl.Dungeons.Tile

  @valid_attrs %{row: 42, col: 42, tile_template_id: 2, level_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Tile.changeset(%Tile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = Tile.changeset(%Tile{}, Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Tile.changeset(%Tile{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = Tile.changeset(%Tile{}, Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end

  DungeonCrawl.SharedTests.handles_state_variables_and_values_correctly(Tile)
end

defmodule DungeonCrawl.Dungeon.SpawnLocationTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon.SpawnLocation

  @valid_attrs %{row: 20, col: 40, dungeon_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @valid_attrs, 19, 39)
    assert changeset.valid?
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @valid_attrs, 39, 19)
    refute changeset.valid?
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @valid_attrs, -1, 19)
    refute changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @invalid_attrs, 40, 40)
    refute changeset.valid?
  end
end

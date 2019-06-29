defmodule DungeonCrawl.Dungeon.MapTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon.Map

  @valid_attrs %{name: "BobDungeon", width: 42, height: 40, version: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Map.changeset(%Map{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Map.changeset(%Map{}, @invalid_attrs)
    refute changeset.valid?
  end
end

defmodule DungeonCrawl.Dungeons.LevelTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons.Level

  @valid_attrs %{name: "BobDungeon", width: 42, height: 40, dungeon_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Level.changeset(%Level{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = Level.changeset(%Level{}, Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Level.changeset(%Level{}, @invalid_attrs)
    refute changeset.valid?
    changeset = Level.changeset(%Level{}, %{name: "test"})
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = Level.changeset(%Level{}, Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end
end

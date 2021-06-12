defmodule DungeonCrawl.Dungeons.DungeonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons.Dungeon

  @valid_attrs %{name: "BobDungeon", version: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Dungeon.changeset(%Dungeon{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = Dungeon.changeset(%Dungeon{}, Elixir.Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Dungeon.changeset(%Dungeon{}, @invalid_attrs)
    refute changeset.valid?
    changeset = Dungeon.changeset(%Dungeon{}, %{name: "test", state: "derp"})
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = Dungeon.changeset(%Dungeon{}, Elixir.Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end
end

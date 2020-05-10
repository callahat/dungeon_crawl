defmodule DungeonCrawl.Dungeon.MapTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon.Map

  @valid_attrs %{name: "BobDungeon", width: 42, height: 40, version: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Map.changeset(%Map{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with valid state values" do
    changeset = Map.changeset(%Map{}, Elixir.Map.put(@valid_attrs, :state, "health: 100"))
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Map.changeset(%Map{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset with invalid state values" do
    changeset = Map.changeset(%Map{}, Elixir.Map.put(@valid_attrs, :state, "derp"))
    refute changeset.valid?
  end
end

defmodule DungeonCrawl.Dungeons.LevelTest do
  use DungeonCrawl.DataCase

  require DungeonCrawl.SharedTests

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons.Level

  @valid_attrs %{name: "BobDungeon", width: 42, height: 40, dungeon_id: 1, state: nil}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Level.changeset(%Level{}, @valid_attrs)
    assert changeset.valid?
    refute Map.has_key?(changeset.changes, :state)
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

  test "level number must be unique for dungeon" do
    level = insert_autogenerated_level()
    changeset = Level.changeset(
                  %Level{},
                  Map.take(level, [:number, :name, :dungeon_id, :height, :width])
                )
    assert {:error, %{errors: [number: {"Level Number already exists", _}]}} = Repo.insert(changeset)
  end

  DungeonCrawl.SharedTests.handles_state_variables_and_values_correctly(Level)
end

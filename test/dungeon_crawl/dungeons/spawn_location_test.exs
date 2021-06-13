defmodule DungeonCrawl.Dungeons.SpawnLocationTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons.SpawnLocation

  @valid_attrs %{row: 19, col: 39, level_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @valid_attrs, 20, 40)
    assert changeset.valid?
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @valid_attrs, 40, 20)
    refute changeset.valid?
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @valid_attrs, -1, 19)
    refute changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = SpawnLocation.changeset(%SpawnLocation{}, @invalid_attrs, 40, 40)
    refute changeset.valid?
  end

  test "no duplicate spawn locations" do
    level = insert_autogenerated_level()
    changeset = SpawnLocation.changeset(%SpawnLocation{}, %{level_id: level.id, row: 1, col: 3}, 20, 20)
    assert {:ok, _} = Repo.insert(changeset)
    assert {:error, %{errors: [level_id: {"Spawn location already exists", _}]}} = Repo.insert(changeset)
  end
end

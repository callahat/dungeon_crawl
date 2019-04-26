defmodule DungeonCrawl.PlayerLocationTest do
  use DungeonCrawl.ModelCase

  alias DungeonCrawl.PlayerLocation

  @valid_attrs %{col: 42, row: 42, user_id_hash: "some content", dungeon_id: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = PlayerLocation.changeset(%PlayerLocation{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = PlayerLocation.changeset(%PlayerLocation{}, @invalid_attrs)
    refute changeset.valid?
  end
end

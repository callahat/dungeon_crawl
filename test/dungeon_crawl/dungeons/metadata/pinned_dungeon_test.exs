defmodule DungeonCrawl.Dungeons.Metadata.PinnedDungeonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons.Metadata.PinnedDungeon

  @valid_attrs %{line_identifier: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = PinnedDungeon.changeset(%PinnedDungeon{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = PinnedDungeon.changeset(%PinnedDungeon{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "line_identifier must be unique" do
    changeset = PinnedDungeon.changeset(
                  %PinnedDungeon{},
                  @valid_attrs
                )

    assert {:ok, %PinnedDungeon{}} = Repo.insert(changeset)
    assert {:error, %{errors: [line_identifier: {"already pinned", _}]}} = Repo.insert(changeset)
  end
end

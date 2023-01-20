defmodule DungeonCrawl.Dungeons.Metadata.FavoriteDungeonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons.Metadata.FavoriteDungeon

  @valid_attrs %{user_id_hash: "asdf", line_identifier: 1}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = FavoriteDungeon.changeset(%FavoriteDungeon{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = FavoriteDungeon.changeset(%FavoriteDungeon{}, @invalid_attrs)
    refute changeset.valid?
    changeset = FavoriteDungeon.changeset(%FavoriteDungeon{}, %{line_identifier: 1})
    refute changeset.valid?
    changeset = FavoriteDungeon.changeset(%FavoriteDungeon{}, %{user_id_hash: "asdf"})
    refute changeset.valid?
  end

  test "user_id_hash and line_identifier must be unique" do
    changeset = FavoriteDungeon.changeset(
                  %FavoriteDungeon{},
                  @valid_attrs
                )

    assert {:ok, %FavoriteDungeon{}} = Repo.insert(changeset)
    assert {:error, %{errors: [user_id_hash: {"already a favorite", _}]}} = Repo.insert(changeset)

    changeset2 = FavoriteDungeon.changeset(
      %FavoriteDungeon{},
      Map.put(@valid_attrs, :line_identifier, 2)
    )
    assert {:ok, %FavoriteDungeon{}} = Repo.insert(changeset2)

    changeset2 = FavoriteDungeon.changeset(
      %FavoriteDungeon{},
      Map.put(@valid_attrs, :user_id_hash, "zxcv")
    )
    assert {:ok, %FavoriteDungeon{}} = Repo.insert(changeset2)
  end
end

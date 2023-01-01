defmodule DungeonCrawl.Dungeons.MetadataTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons.Metadata
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Account.User

  describe "favorite_dungeons" do
    alias DungeonCrawl.Dungeons.Metadata.FavoriteDungeon

    test "favorite" do
      dungeon = %Dungeon{line_identifier: 1}
      user = %User{user_id_hash: "asdf"}

      assert {:ok, favorite} = Metadata.favorite(dungeon, user)
      assert {:error, _} = Metadata.favorite(dungeon, user)
    end

    test "unfavorite" do
      dungeon = %Dungeon{line_identifier: 1}
      user = %User{user_id_hash: "asdf"}

      assert {:ok, favorite} = Metadata.favorite(dungeon, user)

      assert {:ok, favorite} = Metadata.unfavorite(dungeon, user)
      assert {:error, "favorite not found"} = Metadata.unfavorite(dungeon, user)
    end
  end
end

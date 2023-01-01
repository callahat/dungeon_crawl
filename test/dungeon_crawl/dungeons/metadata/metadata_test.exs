defmodule DungeonCrawl.Dungeons.MetadataTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons.Metadata
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Account.User

  describe "favorite_dungeons" do
    test "favorite/2" do
      assert {:ok, _favorite} = Metadata.favorite(1, "asdf")
      assert {:error, _} = Metadata.favorite(1, "asdf")
    end

    test "favorite/2 alternate params" do
      dungeon = %Dungeon{line_identifier: 1}
      user = %User{user_id_hash: "asdf"}

      assert {:ok, _favorite} = Metadata.favorite(dungeon, user)
      assert {:error, _} = Metadata.favorite(dungeon, user)
    end

    test "unfavorite/2" do
      assert {:ok, favorite} = Metadata.favorite(1, "asdf")

      assert {:ok, ^favorite} = Metadata.unfavorite(1, "asdf")
      assert {:error, "favorite not found"} = Metadata.unfavorite(1, "asdf")
    end

    test "unfavorite/2 alternate params" do
      dungeon = %Dungeon{line_identifier: 1}
      user = %User{user_id_hash: "asdf"}

      assert {:ok, favorite} = Metadata.favorite(dungeon, user)

      assert {:ok, ^favorite} = Metadata.unfavorite(dungeon, user)
      assert {:error, "favorite not found"} = Metadata.unfavorite(dungeon, user)
    end
  end
end

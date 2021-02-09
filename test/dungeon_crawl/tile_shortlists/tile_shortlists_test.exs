defmodule DungeonCrawl.TileShortlistsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileShortlists

  describe "tile_shortlist" do
    def tile_shortlist_fixture(user_id, attrs \\ %{}) do
      {:ok, tile_shortlist} =
        TileShortlists.add_to_shortlist(user_id, attrs)

      tile_shortlist
    end

    setup do
      user1 = insert_user(%{name: "one"})
      user2 = insert_user(%{name: "two"})

      tile1 = tile_shortlist_fixture(user1.id, %{character: "X"})
      tile2 = tile_shortlist_fixture(user1.id, %{character: "Y"})
      tile3 = tile_shortlist_fixture(user2.id, %{character: "Z"})

      %{user1: user1, user2: user2, tile1: tile1, tile2: tile2, tile3: tile3}
    end

    test "list_tiles/0 returns all tile_shortlists" do
      assert shortlist = TileShortlists.list_tiles()
      assert length(shortlist) == 3
    end

    test "list_tiles/1 returns all tile_shortlists for the user", config do
      other_user = insert_user()

      assert TileShortlists.list_tiles(other_user) == []
      assert TileShortlists.list_tiles(config.user1) == [config.tile2, config.tile1]
      assert TileShortlists.list_tiles(config.user2) == [config.tile3]
    end

    test "add_to_shortlist/2", config do
      assert {:ok, added_tile} = TileShortlists.add_to_shortlist(config.user2, %{character: "A"})
      assert %{character: "A"} = added_tile
      assert TileShortlists.list_tiles(config.user2) == [added_tile, config.tile3]
    end

    test "add_to_shortlist/2 drops the oldest first to maintain a list that is short", config do
      Enum.each (?a)..(?a+18), fn(i) -> TileShortlists.add_to_shortlist(config.user1, %{character: "#{[i]}"}) end

      assert list = TileShortlists.list_tiles(config.user1)
      assert length(list) == 20

      last_character = "#{[(?a+18)]}"
      assert %{character: ^last_character} = Enum.at(list, 0)
      assert %{character: "Y"} = Enum.at(list, 19)
    end
  end
end

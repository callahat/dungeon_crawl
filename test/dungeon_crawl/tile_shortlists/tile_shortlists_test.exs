defmodule DungeonCrawl.TileShortlistsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileShortlists
  alias DungeonCrawl.TileShortlists.TileShortlist
  alias DungeonCrawl.TileTemplates.TileSeeder

  describe "tile_shortlist" do
    def tile_shortlist_fixture(user_id, attrs \\ %{}) do
      {:ok, tile_shortlist} =
        TileShortlists.add_to_shortlist(user_id, attrs)

      tile_shortlist
    end

    setup do
      TileSeeder.explosion()

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

    test "add_to_shortlist/2 removes the older duplicate(s) when the same entry added", config do
      TileShortlists.add_to_shortlist(config.user2, %{character: "A"})
      [added_tile, tile3] = TileShortlists.list_tiles(config.user2)
      tile3_attrs = Map.take(tile3, TileShortlist.key_attributes())

      assert {:ok, readded_tile3} = TileShortlists.add_to_shortlist(config.user2, tile3_attrs)
      assert TileShortlists.list_tiles(config.user2) == [readded_tile3, added_tile]
    end

    test "add_to_shortlist/2 when its a tile template", config do
      tile_template = insert_tile_template()
      assert {:ok, added_tile} = TileShortlists.add_to_shortlist(config.user2, tile_template)
      expected_character = tile_template.character
      expected_name = tile_template.name
      assert %{character: ^expected_character, name: ^expected_name} = added_tile
      assert TileShortlists.list_tiles(config.user2) == [added_tile, config.tile3]
    end

    test "add_to_shortlist/2 drops the oldest first to maintain a list that is short", config do
      Enum.each (?a)..(?a+28), fn(i) -> TileShortlists.add_to_shortlist(config.user1, %{character: "#{[i]}"}) end

      assert list = TileShortlists.list_tiles(config.user1)
      assert length(list) == 30

      last_character = "#{[(?a+28)]}"
      assert %{character: ^last_character} = Enum.at(list, 0)
      assert %{character: "Y"} = Enum.at(list, 29)
    end

    test "add_to_shortlist/2 but the input is bad", config do
      bad_params = %{name: "1234567890abcdefghijklmnopqrstuvwxyz", state: "bad", script: "#DERP alsobad"}
      assert {:error, changeset} = TileShortlists.add_to_shortlist(config.user1, bad_params)
      assert %{
               script: ["Unknown command: `DERP` - near line 1"],
               state: ["Error parsing around: bad"],
               name: ["should be at most 32 character(s)"]
             } = errors_on(changeset)
    end

    test "add_to_shortlist/2 with ok tile_template_id", config do
      tile_template = insert_tile_template()
      assert {:ok, tile_shortlist} = TileShortlists.add_to_shortlist(config.user1, %{tile_template_id: tile_template.id})
      assert tile_shortlist.tile_template_id == tile_template.id
    end

    test "add_to_shortlist/2 with bad tile_template_id", config do
      assert {:error, changeset} = TileShortlists.add_to_shortlist(config.user1, %{tile_template_id: 12345})
      assert errors_on(changeset).tile_template_id == ["tile template does not exist"]
    end

    test "add_to_shortlist/2 with historic tile_template_id", config do
      tile_template = insert_tile_template(%{deleted_at: NaiveDateTime.utc_now})
      assert {:error, changeset} = TileShortlists.add_to_shortlist(config.user1, %{tile_template_id: tile_template.id})
      assert errors_on(changeset).tile_template_id == ["cannot shortlist an historic tile template"]
    end

    test "seed_shortlist/1", config do
      assert [tile1, tile2] = TileShortlists.list_tiles(config.user1)
      assert :ok = TileShortlists.seed_shortlist(config.user1)
      assert [tile1a, tile2a | seeded_tiles] = TileShortlists.list_tiles(config.user1)

      assert length(seeded_tiles) == 20
      refute Enum.member?(seeded_tiles, tile1)
      refute Enum.member?(seeded_tiles, tile2)

      assert Map.drop(tile1, [:id, :inserted_at, :updated_at]) == Map.drop(tile1a, [:id, :inserted_at, :updated_at])
      assert Map.drop(tile2, [:id, :inserted_at, :updated_at]) == Map.drop(tile2a, [:id, :inserted_at, :updated_at])
    end

    test "seed_shortlist/1 when shortlist already full", config do
      Enum.each (?a)..(?a+27), fn(i) -> TileShortlists.add_to_shortlist(config.user2, %{character: "#{[i]}"}) end

      assert existing_list = TileShortlists.list_tiles(config.user2)
      assert :ok = TileShortlists.seed_shortlist(config.user2)

      [seeded_tile | existing_list_reverse] = TileShortlists.list_tiles(config.user2)
                                              |> Enum.reverse

      refute Enum.member?(existing_list, seeded_tile)
      assert %{name: "Floor", character: "."} = seeded_tile

      assert Enum.map(Enum.reverse(existing_list_reverse), &(Map.drop(&1, [:id, :inserted_at, :updated_at]))) ==
             Enum.map(existing_list, &(Map.drop(&1, [:id, :inserted_at, :updated_at])))
    end

    test "hash/1", config do
      assert "S2irOEf+2n1sYsH7y+6/o16rc1HtXnj03a3qXfZLgBU=" = TileShortlists.hash(config.tile1)
    end
  end
end

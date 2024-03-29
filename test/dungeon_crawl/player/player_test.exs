defmodule DungeonCrawl.PlayerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Equipment

  describe "player_locations" do
    alias DungeonCrawl.Player.Location

    import DungeonCrawl.GamesFixtures

    @valid_attrs %{user_id_hash: "some content"}
    @invalid_attrs %{user_id_hash: nil}

    def location_fixture(attrs \\ %{user_id_hash: "test_hash"}) do
      level_instance = insert_autogenerated_level_instance()
      insert_player_location(Map.merge(%{level_instance_id: level_instance.id}, attrs))
    end

    test "get_location/1" do
      location1 = location_fixture(%{tile_instance_id: nil})
      location2 = location_fixture()
      assert Player.get_location(%{id: location1.id}) == location1
      assert Player.get_location(%{id: location2.id}) == location2
      refute Player.get_location(location1.user_id_hash)
      assert Player.get_location(location2.user_id_hash) == location2
    end

    test "get_location!/1" do
      _location1 = location_fixture(%{user_id_hash: "getLocation", tile_instance_id: nil})
      location2 = location_fixture(%{user_id_hash: "getLocation"})
      location3 = location_fixture(%{user_id_hash: "third"})
      _location4 = location_fixture(%{user_id_hash: "fourth", tile_instance_id: nil})
      assert Player.get_location!("getLocation") == location2
      assert Player.get_location!("third") == location3
      assert_raise Ecto.NoResultsError, fn -> Player.get_location!("fourth") end
    end

    test "update_location!/2" do
      location = location_fixture()
      assert location.tile_instance_id != nil
      assert location = Player.update_location!(location, %{tile_instance_id: nil})
      assert location.tile_instance_id == nil
    end

    test "dungeon_id/1" do
      level_instance = insert_autogenerated_level_instance()
                       |> Repo.preload(:dungeon)
      location = location_fixture(%{level_instance_id: level_instance.id})

      assert Player.dungeon_id(location) == level_instance.dungeon.dungeon_id
      assert Player.dungeon_id(location.id) == level_instance.dungeon.dungeon_id
    end

    test "is_crawling?/1" do
      user = insert_user(%{user_id_hash: "notcrawling"})
      location = location_fixture(%{user_id_hash: "crawlingplayer"})
      assert Player.is_crawling?(location.user_id_hash)
      assert Player.is_crawling?(location)
      refute Player.is_crawling?("fakeplayer")
      refute Player.is_crawling?(user.user_id_hash)

      # When not crawling, indicated by a nil tile_instance_id - this is just a saved location
      location2 = location_fixture(%{user_id_hash: "notcrawlingplayer", tile_instance_id: nil})
      refute Player.is_crawling?(location2.user_id_hash)
      refute Player.is_crawling?(location2)
    end

    test "has_saved_games?/1" do
      user = insert_user(%{user_id_hash: "nosaves"})
      save = save_fixture()
      assert Player.has_saved_games?(save.user_id_hash)
      refute Player.has_saved_games?(user.user_id_hash)
    end

    test "create_location/1 with valid data returns a location" do
      level_instance = insert_autogenerated_level_instance()
      player_tile = insert_player_tile(Map.merge(%{level_instance_id: level_instance.id}, @valid_attrs))
      assert {:ok, %Location{} = _location} = Player.create_location(Map.merge(%{tile_instance_id: player_tile.id}, @valid_attrs))
    end

    test "create_location/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Player.create_location(Map.merge(%{}, @invalid_attrs))
    end

    test "create_location!/1 with good params returns a location" do
      level_instance = insert_autogenerated_level_instance()
      player_tile = insert_player_tile(Map.merge(%{level_instance_id: level_instance.id}, @valid_attrs))
      assert %Location{} = _location = Player.create_location!(Map.merge(%{tile_instance_id: player_tile.id}, @valid_attrs))
    end

    test "create_location_on_spawnable_space/3 returns a location" do
      Equipment.Seeder.gun
      insert_item(%{name: "Fists"})

      dungeon_instance = insert_autogenerated_dungeon_instance(%{state: %{"starting_lives" => 3, "starting_equipment" => ["fists", "gun"]}})
      avatar = %{color: "black", background_color: "whitesmoke", name: "Anon"}
      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, "goodhash", avatar)
      assert Repo.preload(location, :tile).tile
      assert Repo.preload(location, :tile).tile.character == "@" # its in the basic tile template seeds
      assert Repo.preload(location, :tile).tile.name == "AnonPlayer" # the default when no player account
      assert Repo.preload(location, :tile).tile.state["lives"] == 3
      assert Repo.preload(location, :tile).tile.state["equipped"] == "fists"
      assert Repo.preload(location, :tile).tile.state["equipment"] == ["fists", "gun"]

      # works when entrance is not set
      Repo.preload(dungeon_instance, [levels: :level]).levels
      |> Enum.each(fn(level) -> Dungeons.update_level(level.level, %{entrance: false}) end)

      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, "differenthash", avatar)
      assert Repo.preload(location, :tile).tile
      assert Repo.preload(location, :tile).tile.character == "@" # its in the basic tile template seeds

      # when player has an account
      user = insert_user()
      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, user.user_id_hash, avatar)
      assert Repo.preload(location, :tile).tile.name == user.name # its derived
    end

    test "create_location_on_spawnable_space/3 returns a location when level instance not yet set" do
      Equipment.Seeder.gun
      insert_item(%{name: "Fists"})

      dungeon_instance = insert_autogenerated_dungeon_instance(%{headers_only: true})
      avatar = %{color: "black", background_color: "whitesmoke", name: "Anon"}
      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, "goodhash", avatar)
      assert Repo.preload(location, :tile).tile
    end

    test "create_location_on_spawnable_space/3 returns a location when spawn locations exist" do
      Equipment.Seeder.gun

      dungeon_instance = insert_autogenerated_dungeon_instance()
      avatar = %{color: "black", background_color: "whitesmoke", name: "Anon"}

      Dungeons.set_spawn_locations(Enum.at(Repo.preload(dungeon_instance, :levels).levels, 0).level_id, [{10,10}])
      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, "goodhash", avatar)
      assert Repo.preload(location, :tile).tile
      assert Repo.preload(location, :tile).tile.character == "@" # its in the basic tile template seeds
      assert Repo.preload(location, :tile).tile.row == 10
      assert Repo.preload(location, :tile).tile.col == 10

      # works when entrance is not set
      Repo.preload(dungeon_instance, [levels: :level]).levels
      |> Enum.each(fn(level) -> Dungeons.update_level(level.level, %{entrance: false}) end)

      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, "differenthash", avatar)
      assert Repo.preload(location, :tile).tile
      assert Repo.preload(location, :tile).tile.character == "@" # its in the basic tile template seeds
      assert Repo.preload(location, :tile).tile.row == 10
      assert Repo.preload(location, :tile).tile.col == 10
      assert Repo.preload(location, :tile).tile.z_index > 1

      # puts location on z_index higher than whats currently there
      Repo.preload(dungeon_instance, [levels: :level]).levels
      |> Enum.each(fn(level) ->
           Repo.preload(level, :tiles).tiles
           |> Enum.each(fn(tile) ->
             DungeonInstances.update_tiles([Tile.changeset(tile, %{z_index: 3})])
           end)
         end)
      assert %Location{} = location = Player.create_location_on_spawnable_space(dungeon_instance, "differenthash", avatar)
      assert Repo.preload(location, :tile).tile.z_index > 3
    end

    test "set_tile_instance_id/1" do
      location = location_fixture()
      assert tile_instance_id = location.tile_instance_id
      location = Player.set_tile_instance_id(location, nil)
      refute location.tile_instance_id
      location = Player.set_tile_instance_id(location, tile_instance_id)
      assert location.tile_instance_id == tile_instance_id
    end

    test "delete_location!/1 deletes the location associated with the user_id_hash" do
      location_fixture(%{user_id_hash: "deletedHash"})
      assert %Location{} = Player.delete_location!("deletedHash")
      assert_raise Ecto.NoResultsError, fn -> Player.get_location!("deletedHash")  end
    end

    test "delete_location!/1 deletes the location but not the dungeon" do
      location = location_fixture() |> Repo.preload([tile: :level])
      instance_id = location.tile.level_instance_id
      level_instance = Repo.preload(location, [tile: :level]).tile.level
      dungeon = Repo.preload(location, [tile: [level: [dungeon: :dungeon]]]).tile.level.dungeon.dungeon
      Repo.get(DungeonInstances.Dungeon, level_instance.dungeon_instance_id)
      |> Ecto.Changeset.cast(%{autogenerated: false},[:autogenerated])
      |> Repo.update!

      assert %Location{} = Player.delete_location!(location)
      assert_raise Ecto.NoResultsError, fn -> Player.get_location!(location.user_id_hash)  end
      assert Repo.get(DungeonInstances.Dungeon, level_instance.dungeon_instance_id)
      assert Repo.get(DungeonInstances.Level, instance_id)
      assert Repo.get(Dungeons.Dungeon, dungeon.id)
    end

    test "change_location/2 returns a location changeset" do
      location = location_fixture()
      assert %Ecto.Changeset{} = Player.change_location(location)
    end

    test "players_in_level/1 returns the number of players id given a level instance" do
      assert 0 == Player.players_in_level(%DungeonInstances.Level{id: 9999999})
      location = location_fixture() |> Repo.preload(:tile)
      assert 1 == Player.players_in_level(%DungeonInstances.Level{id: location.tile.level_instance_id})
      assert 1 == Player.players_in_level(%{instance_id: location.tile.level_instance_id})
    end

    test "players_in_level/1 returns the number of players id given a level" do
      assert 0 == Player.players_in_level(%Dungeons.Level{id: 9999999})
      location = location_fixture() |> Repo.preload(tile: [:level])
      assert 1 == Player.players_in_level(%Dungeons.Level{id: location.tile.level.level_id})
    end

    test "players_in_instance/1 returns the player locations given an instance" do
      assert [] == Player.players_in_instance(%DungeonInstances.Level{id: 9999999})
      location = location_fixture()
      assert [location] == Player.players_in_instance(%DungeonInstances.Level{id: Repo.preload(location, :tile).tile.level_instance_id})
    end

    test "get_dungeon/1" do
      location = location_fixture()
      dungeon = Repo.preload(location, [tile: [level: [dungeon: :dungeon]]]).tile.level.dungeon.dungeon
      assert dungeon == Player.get_dungeon(location)
    end
  end
end

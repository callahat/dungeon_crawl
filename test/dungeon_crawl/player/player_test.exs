defmodule DungeonCrawl.PlayerTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.MapTile

  describe "player_locations" do
    alias DungeonCrawl.Player.Location

    @valid_attrs %{user_id_hash: "some content"}
    @invalid_attrs %{user_id_hash: nil}

    def location_fixture(attrs \\ %{user_id_hash: "test_hash"}) do
      instance = insert_autogenerated_dungeon_instance()
      insert_player_location(Map.merge(%{map_instance_id: instance.id}, attrs))
    end

    test "get_location/1" do
      location = location_fixture()
      assert Player.get_location(%{id: location.id}) == location
    end

    test "get_location!/1" do
      location = location_fixture(%{user_id_hash: "getLocation"})
      assert Player.get_location!("getLocation") == location
    end

    test "create_location/1 with valid data returns a location" do
      instance = insert_autogenerated_dungeon_instance()
      player_map_tile = insert_player_map_tile(Map.merge(%{map_instance_id: instance.id}, @valid_attrs))
      assert {:ok, %Location{} = _location} = Player.create_location(Map.merge(%{map_tile_instance_id: player_map_tile.id}, @valid_attrs))
    end

    test "create_location/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Player.create_location(Map.merge(%{}, @invalid_attrs))
    end

    test "create_location!/1 with good params returns a location" do
      instance = insert_autogenerated_dungeon_instance()
      player_map_tile = insert_player_map_tile(Map.merge(%{map_instance_id: instance.id}, @valid_attrs))
      assert %Location{} = _location = Player.create_location!(Map.merge(%{map_tile_instance_id: player_map_tile.id}, @valid_attrs))
    end

    test "create_location_on_spawnable_space/3 returns a location" do
      map_set_instance = insert_autogenerated_map_set_instance(%{state: "starting_lives: 3"})
      avatar = %{color: "black", background_color: "whitesmoke", name: "Anon"}
      assert {:ok, %Location{} = location} = Player.create_location_on_spawnable_space(map_set_instance, "goodhash", avatar)
      assert Repo.preload(location, :map_tile).map_tile
      assert Repo.preload(location, :map_tile).map_tile.character == "@" # its in the basic tile template seeds
      assert Repo.preload(location, :map_tile).map_tile.name == "AnonPlayer" # the default when no player account
      assert Repo.preload(location, :map_tile).map_tile.state =~ ~r/lives: 3/

      # works when entrance is not set
      Repo.preload(map_set_instance, [maps: :dungeon]).maps
      |> Enum.each(fn(map) -> Dungeons.update_map(map.dungeon, %{entrance: false}) end)

      assert {:ok, %Location{} = location} = Player.create_location_on_spawnable_space(map_set_instance, "differenthash", avatar)
      assert Repo.preload(location, :map_tile).map_tile
      assert Repo.preload(location, :map_tile).map_tile.character == "@" # its in the basic tile template seeds

      # when player has an account
      user = insert_user()
      assert {:ok, %Location{} = location} = Player.create_location_on_spawnable_space(map_set_instance, user.user_id_hash, avatar)
      assert Repo.preload(location, :map_tile).map_tile.name == user.name # its derived
    end

    test "create_location_on_spawnable_space/3 returns a location when spawn locations exist" do
      map_set_instance = insert_autogenerated_map_set_instance()
      avatar = %{color: "black", background_color: "whitesmoke", name: "Anon"}

      Dungeons.set_spawn_locations(Enum.at(Repo.preload(map_set_instance, :maps).maps, 0).map_id, [{10,10}])
      assert {:ok, %Location{} = location} = Player.create_location_on_spawnable_space(map_set_instance, "goodhash", avatar)
      assert Repo.preload(location, :map_tile).map_tile
      assert Repo.preload(location, :map_tile).map_tile.character == "@" # its in the basic tile template seeds
      assert Repo.preload(location, :map_tile).map_tile.row == 10
      assert Repo.preload(location, :map_tile).map_tile.col == 10

      # works when entrance is not set
      Repo.preload(map_set_instance, [maps: :dungeon]).maps
      |> Enum.each(fn(map) -> Dungeons.update_map(map.dungeon, %{entrance: false}) end)

      assert {:ok, %Location{} = location} = Player.create_location_on_spawnable_space(map_set_instance, "differenthash", avatar)
      assert Repo.preload(location, :map_tile).map_tile
      assert Repo.preload(location, :map_tile).map_tile.character == "@" # its in the basic tile template seeds
      assert Repo.preload(location, :map_tile).map_tile.row == 10
      assert Repo.preload(location, :map_tile).map_tile.col == 10
      assert Repo.preload(location, :map_tile).map_tile.z_index > 1

      # puts location on z_index higher than whats currently there
      Repo.preload(map_set_instance, [maps: :dungeon]).maps
      |> Enum.each(fn(map) ->
           Repo.preload(map, :dungeon_map_tiles).dungeon_map_tiles
           |> Enum.each(fn(map_tile) ->
             DungeonInstances.update_map_tiles([MapTile.changeset(map_tile, %{z_index: 3})])
           end)
         end)
      assert {:ok, %Location{} = location} = Player.create_location_on_spawnable_space(map_set_instance, "differenthash", avatar)
      assert Repo.preload(location, :map_tile).map_tile.z_index > 3
    end

    test "delete_location!/1 deletes the location and deletes the autogenerated map set" do
      location = location_fixture() |> Repo.preload([map_tile: :dungeon])
      instance_id = location.map_tile.map_instance_id
      dungeon_id = location.map_tile.dungeon.map_id
      map_set = Repo.preload(location, [map_tile: [dungeon: [map_set: :map_set]]]).map_tile.dungeon.map_set.map_set
      assert %Location{} = Player.delete_location!(location)
      assert_raise Ecto.NoResultsError, fn -> Player.get_location!(location.user_id_hash) end
      refute Repo.get(Dungeons.Map, dungeon_id)
      refute Repo.get(DungeonInstances.Map, instance_id)
      refute Repo.get(Dungeons.MapSet, map_set.id)
    end

    test "delete_location!/1 deletes the location associated with the user_id_hash" do
      location_fixture(%{user_id_hash: "deletedHash"})
      assert %Location{} = Player.delete_location!("deletedHash")
      assert_raise Ecto.NoResultsError, fn -> Player.get_location!("deletedHash")  end
    end

    test "delete_location!/1 deletes the location but not the non autogen map set" do
      location = location_fixture() |> Repo.preload([map_tile: :dungeon])
      instance_id = location.map_tile.map_instance_id
      dungeon_instance = Repo.preload(location, [map_tile: :dungeon]).map_tile.dungeon
      map_set = Repo.preload(location, [map_tile: [dungeon: [map_set: :map_set]]]).map_tile.dungeon.map_set.map_set
      Repo.get(DungeonInstances.MapSet, dungeon_instance.map_set_instance_id)
      |> Ecto.Changeset.cast(%{autogenerated: false},[:autogenerated])
      |> Repo.update!

      assert %Location{} = Player.delete_location!(location)
      assert_raise Ecto.NoResultsError, fn -> Player.get_location!(location.user_id_hash)  end
      refute Repo.get(DungeonInstances.MapSet, instance_id)
      assert Repo.get(Dungeons.MapSet, map_set.id)
    end

    test "delete_location!/1 does not delete the instance if other players present" do

    end

    test "change_location/2 returns a location changeset" do
      location = location_fixture()
      assert %Ecto.Changeset{} = Player.change_location(location)
    end

    test "players_in_dungeon/1 returns the number of players id given a dungeon instance" do
      assert 0 == Player.players_in_dungeon(%DungeonInstances.Map{id: 9999999})
      location = location_fixture() |> Repo.preload(:map_tile)
      assert 1 == Player.players_in_dungeon(%DungeonInstances.Map{id: location.map_tile.map_instance_id})
    end

    test "players_in_dungeon/1 returns the number of players id given a dungeon" do
      assert 0 == Player.players_in_dungeon(%Dungeons.Map{id: 9999999})
      location = location_fixture() |> Repo.preload(map_tile: [:dungeon])
      assert 1 == Player.players_in_dungeon(%Dungeons.Map{id: location.map_tile.dungeon.map_id})
    end

    test "players_in_instance/1 returns the player locations given an instance" do
      assert [] == Player.players_in_instance(%DungeonInstances.Map{id: 9999999})
      location = location_fixture()
      assert [location] == Player.players_in_instance(%DungeonInstances.Map{id: Repo.preload(location, :map_tile).map_tile.map_instance_id})
    end

    test "get_dungeon/1" do
      location = location_fixture()
      map_set = Repo.preload(location, [map_tile: [dungeon: [map_set: :map_set]]]).map_tile.dungeon.map_set.map_set
      assert map_set == Player.get_map_set(location)
    end
  end
end

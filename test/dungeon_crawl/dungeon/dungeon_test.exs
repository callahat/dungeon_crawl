defmodule DungeonCrawl.DungeonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.MapGenerators.TestRooms

  describe "map_sets" do
    alias DungeonCrawl.Dungeon.Map
    alias DungeonCrawl.Dungeon.MapSet

    @valid_attrs %{name: "some content"}
    @valid_map_attrs %{height: 20, width: 20}
    @update_attrs %{name: "new name"}
    @invalid_attrs %{name: ""}

    def map_set_fixture(attrs \\ %{}) do
      {:ok, map_set} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Dungeon.create_map_set()

      map_set
    end

    test "list_map_sets/0 returns all map_sets" do
      map_set = map_set_fixture()
      assert Dungeon.list_map_sets() == [map_set]
    end

    test "list_map_sets/1 returns all map_sets owned by the user" do
      map_set_fixture()
      user = insert_user()
      map_set = map_set_fixture(%{user_id: user.id})
      assert Dungeon.list_map_sets(user) == [map_set]
    end

    test "list_map_sets/1 returns all soft deleted map_sets" do
      map_set_deleted = map_set_fixture()
      map_set_fixture()
      Dungeon.delete_map_set(map_set_deleted)
      assert Dungeon.list_map_sets(:soft_deleted) == [Dungeon.get_map_set(map_set_deleted.id)]
    end

    test "list_map_sets_with_player_count/0 returns all dungeons preloaded with the players in the map instances" do
      map_set_fixture = map_set_fixture()
      map = insert_autogenerated_dungeon_instance(%{map_set_id: map_set_fixture.id})

      assert [%{map_set_id: map_set_id, map_set: map_set}] = Dungeon.list_map_sets_with_player_count()

      assert map_set_id == map_set_fixture.id
      assert Enum.count(map_set.locations) == 0

      _p1 = insert_player_location(%{map_instance_id: map.id})
      _p2 = insert_player_location(%{map_instance_id: map.id, user_id_hash: "different"})

      assert [%{map_set_id: map_set_id, map_set: map_set}] = Dungeon.list_map_sets_with_player_count()

      assert map_set_id == map_set_fixture.id
      assert Enum.count(map_set.locations) == 2
    end

    test "list_active_map_sets_with_player_count/0 returns all active dungeons preloaded with the players in the map instances" do
      insert_stubbed_map_set_instance(%{active: false})
      insert_stubbed_map_set_instance(%{active: true, deleted_at: NaiveDateTime.utc_now |> NaiveDateTime.truncate(:second)})

      msi = insert_stubbed_map_set_instance(%{active: true})
      map = Repo.preload(msi, :maps).maps |> Enum.at(0)

      insert_player_location(%{map_instance_id: map.id})

      assert [%{map_set_id: map_set_id, map_set: map_set}] = Dungeon.list_active_map_sets_with_player_count()

      assert map_set_id == msi.map_set_id
      assert Enum.count(map_set.locations) == 1
    end

    test "instance_count/1 returns the number of instances existing for the dungeon" do
      assert Dungeon.instance_count(1) == 0

      msi = insert_autogenerated_map_set_instance(%{active: false})

      assert Dungeon.instance_count(msi.map_set_id) == 1
      assert Dungeon.instance_count(%MapSet{id: msi.map_set_id}) == 1
    end

    test "get_map_set!/1 returns the map with given id" do
      map_set = map_set_fixture()
      assert map_set == Dungeon.get_map_set!(map_set.id)
      assert map_set == Dungeon.get_map_set(map_set.id)
    end

    test "next_version_exists?/1 is true if the map set has a next version" do
      map_set = insert_stubbed_map_set()
      insert_stubbed_map_set(%{previous_version_id: map_set.id})
      assert Dungeon.next_version_exists?(map_set)
    end

    test "next_version_exists?/1 is false if the map does not have a next version" do
      map_set = insert_stubbed_map_set()
      refute Dungeon.next_version_exists?(map_set)
    end

    test "create_map_set/1 with valid data creates a map" do
      assert {:ok, %MapSet{} = _map_set} = Dungeon.create_map_set(@valid_attrs)
    end

    test "create_map_set/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeon.create_map_set(@invalid_attrs)
    end

    test "create_new_map_version/1 does not create a new version of an inactive map" do
      map_set = insert_stubbed_map_set(%{active: false})
      assert {:error, "Inactive map set"} = Dungeon.create_new_map_set_version(map_set)
    end

    test "create_new_map_version/1 does not create a new version if any maps have legacy dimensions which are now invalid" do
      map_set = insert_stubbed_map_set(%{active: true}, %{height: 40, width: 40})
      DungeonCrawl.Admin.update_setting(%{autogen_height: 20, autogen_width: 20, max_width: 20, max_height: 20})
      assert {:error, :new_maps, _, _} = Dungeon.create_new_map_set_version(map_set)
    end

    test "create_new_map_version/1 creates a new version" do
      map_set = insert_autogenerated_map_set(%{active: true})
      map = Repo.preload(map_set, :dungeons).dungeons |> Enum.at(0)
      Repo.insert_all(Dungeon.SpawnLocation, [%{dungeon_id: map.id, row: 1, col: 1}, %{dungeon_id: map.id, row: 1, col: 2}])
      assert {:ok, new_map_set} = Dungeon.create_new_map_set_version(map_set)
      assert new_map_set.version == map_set.version + 1

      assert %MapSet{} = new_map_set
      old_tiles = Repo.preload(map, :dungeon_map_tiles).dungeon_map_tiles
                  |> Enum.map(fn(t) -> Elixir.Map.take(t, [:row, :col, :z_index, :tile_template_id, :character, :color, :background_color, :state, :script]) end)
      old_spawn_locations = Repo.preload(map, :spawn_locations).spawn_locations
                            |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
      new_map = Repo.preload(new_map_set, :dungeons).dungeons |> Enum.at(0)
      new_tiles = Repo.preload(new_map, :dungeon_map_tiles).dungeon_map_tiles
                  |> Enum.map(fn(t) -> Elixir.Map.take(t, [:row, :col, :z_index, :tile_template_id, :character, :color, :background_color, :state, :script]) end)
      new_spawn_locations = Repo.preload(new_map, :spawn_locations).spawn_locations
                            |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
      assert old_tiles == new_tiles
      assert old_spawn_locations == new_spawn_locations
    end

    test "create_new_map_version/1 does not create a new version if the next one exists" do
      map_set = insert_stubbed_map_set(%{active: true})
      insert_stubbed_map_set(%{previous_version_id: map_set.id})
      assert {:error, "New version already exists"} = Dungeon.create_new_map_set_version(map_set)
    end

    test "generate_map_set/4 returns an autogenerated map" do
      assert {:ok, %MapSet{} = map_set} = Dungeon.generate_map_set(TestRooms, @valid_attrs, @valid_map_attrs)
      assert map_set.autogenerated
      assert Enum.at(Repo.preload(map_set, :dungeons).dungeons,0).entrance
    end

    test "generate_map_set/4 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeon.generate_map_set(TestRooms, @invalid_attrs)
      assert {:error, :dungeon, %Ecto.Changeset{}, _others} = Dungeon.generate_map_set(TestRooms, @valid_attrs)
    end

    test "update_map_set/2 with valid data updates the map_set" do
      map_set = map_set_fixture()
      assert {:ok, map_set} = Dungeon.update_map_set(map_set, @update_attrs)
      assert %MapSet{} = map_set
    end

    test "update_map_set/2 with invalid data returns error changeset" do
      map_set = map_set_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeon.update_map_set(map_set, @invalid_attrs)
      assert map_set == Dungeon.get_map_set!(map_set.id)
    end

    test "activate_map_set/1 with map set activtes map set" do
      map_set = map_set_fixture()
      refute map_set.active
      assert {:ok, activated_map_set} = Dungeon.activate_map_set(map_set)
      assert activated_map_set == Dungeon.get_map_set(map_set.id)
      assert activated_map_set.active
    end

    test "activate_map_set/1 soft deletes the previous version" do
      map_set = map_set_fixture()
      new_map_set = map_set_fixture(%{previous_version_id: map_set.id})
      assert {:ok, activated_map_set} = Dungeon.activate_map_set(new_map_set)
      assert Dungeon.get_map_set(map_set.id).deleted_at
      assert Dungeon.get_map_set(new_map_set.id).active
      assert new_map_set.id == activated_map_set.id
    end

    test "activate_map_set/1 with map set that has inactive tiles returns error message" do
      tile_a = insert_tile_template(%{name: "ACT", active: true})
      tile_b = insert_tile_template(%{name: "INT", active: false})
      map_set = insert_stubbed_map_set(%{}, %{},
                  [[Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                                     Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                    Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                                     Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                    Elixir.Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                                     Elixir.Map.take(tile_b, [:character, :color, :background_color, :state, :script]))]])

      assert {:error, error_msg} = Dungeon.activate_map_set(map_set)
      assert error_msg == "Inactive tiles: INT (id: #{tile_b.id}) 1 times"
    end

    test "delete_map_set/1 soft deletes the map set" do
      map_set = map_set_fixture()
      assert {:ok, map_set} = Dungeon.delete_map_set(map_set)
      assert %MapSet{} = map_set
      assert map_set.deleted_at
    end

    test "hard_delete_map_set!/1 deletes the map set" do
      map_set = insert_stubbed_map_set(%{active: true})
      map = Repo.preload(map_set, :dungeons).dungeons |> Enum.at(0)
      Repo.insert_all(Dungeon.SpawnLocation, [%{dungeon_id: map.id, row: 1, col: 1}, %{dungeon_id: map.id, row: 1, col: 2}])
      assert map_set = Dungeon.hard_delete_map_set!(map_set)
      assert %MapSet{} = map_set
      refute DungeonCrawl.Repo.get Dungeon.MapSet, map_set.id
    end

    test "change_map_set/1 returns a map set changeset" do
      map_set = map_set_fixture()
      assert %Ecto.Changeset{} = Dungeon.change_map_set(map_set)
    end
  end

  describe "dungeons" do
    alias DungeonCrawl.Dungeon.Map
    alias DungeonCrawl.Dungeon.MapSet

    @valid_attrs %{name: "some content", height: 40, width: 80}
    @update_attrs %{name: "new name"}
    @invalid_attrs %{height: 1}

    def map_fixture(attrs \\ %{}) do
      {:ok, map_set} = Dungeon.create_map_set(%{name: "map set"})

      {:ok, map} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Elixir.Map.put(:map_set_id, map_set.id)
        |> Dungeon.create_map()

      map
    end

    test "list_dungeons/0 returns all dungeons for a map set" do
      map = map_fixture()
      assert Dungeon.list_dungeons(%MapSet{id: map.map_set_id}) == [map]
    end

    test "list_dungeons_with_player_count/0 returns all dungeons preloaded with the players in the map instances" do
      map_i = insert_autogenerated_dungeon_instance()
      insert_autogenerated_dungeon_instance(%{map_set_id: Repo.preload(map_i, :map_set).map_set.map_set_id})
      msi = Repo.preload(map_i, :map_set).map_set

      assert [%{dungeon_id: dungeon_id1, dungeon: dungeon1}, %{dungeon_id: dungeon_id2, dungeon: dungeon2}] =
               Dungeon.list_dungeons_with_player_count(%MapSet{id: msi.map_set_id})

      assert dungeon2.id == map_i.map_id
      assert Enum.count(Repo.preload(map_i, [dungeon: :locations]).dungeon.locations) == 0

      insert_player_location(%{map_instance_id: map_i.id})
      insert_player_location(%{map_instance_id: map_i.id, user_id_hash: "different"})

      assert [%{dungeon_id: dungeon_id1, dungeon: dungeon1}, %{dungeon_id: dungeon_id2, dungeon: dungeon2}] =
               Dungeon.list_dungeons_with_player_count(%MapSet{id: msi.map_set_id})
      assert Enum.count(Repo.preload(map_i, [dungeon: :locations]).dungeon.locations) == 2
    end

    test "next_level_number/1" do
      map = map_fixture()
      map_set_1 = Repo.preload(map, :map_set).map_set
      map_set_2 = insert_map_set()

      assert Dungeon.next_level_number(map_set_1) == 2
      assert Dungeon.next_level_number(map_set_2) == 1 # has no maps
    end

    test "get_map!/1 returns the map with given id" do
      map = map_fixture()
      assert Dungeon.get_map!(map.id) == map
    end

    test "get_bounding_z_indexes!/1 returns the map's lowest and highest z index for given id" do
      tile_a = insert_tile_template()
      map = insert_stubbed_dungeon(%{},
              [Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                                Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
               Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 2},
                                Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script]))])

      assert Dungeon.get_bounding_z_indexes(map.id) == {0,2}
      assert Dungeon.get_bounding_z_indexes(map) == {0,2}
    end

    test "list_historic_tile_templates/1 when no historic tiles returns an empty array" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      map = insert_stubbed_dungeon(%{},
              [Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                                Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
               Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                                Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
               Elixir.Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                                Elixir.Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])
      assert Dungeon.list_historic_tile_templates(map) == []
    end

    test "list_historic_tile_templates/1 returns array of distinct historic tile templates" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      map = insert_stubbed_dungeon(%{},
              [Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                                Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
               Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                                Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
               Elixir.Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                                Elixir.Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])
      {:ok, tile_a} = DungeonCrawl.TileTemplates.delete_tile_template(tile_a)
      assert Dungeon.list_historic_tile_templates(map) == [tile_a]
    end

    test "create_map/1 with valid data creates a map" do
      assert {:ok, %Map{} = _map} = Dungeon.create_map(Elixir.Map.put(@valid_attrs, :map_set_id, insert_map_set().id))
    end

    test "create_map/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeon.create_map(@invalid_attrs)
    end

    test "generate_map/2 returns an autogenerated map" do
      assert {:ok, %{dungeon: %Map{} = _map}} = Dungeon.generate_map(TestRooms, Elixir.Map.put(@valid_attrs, :map_set_id, insert_map_set().id))
    end

    test "generate_map/2 with invalid data returns error changeset" do
      assert {:error, :dungeon, %Ecto.Changeset{}, _others} = Dungeon.generate_map(TestRooms, @invalid_attrs)
    end

    test "update_map/2 with valid data updates the map" do
      map = map_fixture()
      assert {:ok, map} = Dungeon.update_map(map, @update_attrs)
      assert %Map{} = map
    end

    test "update_map/2 with bigger dimensions creates new emtpy map tiles" do
      map = insert_autogenerated_dungeon()
      refute Dungeon.get_map_tile(map.id, map.width, map.height)
      assert {:ok, _updated_map} = Dungeon.update_map(map, %{width: map.width + 1, height: map.height + 1})
      assert Dungeon.get_map_tile(map.id, map.width, map.height).tile_template_id
    end

    test "update_map/2 with smaller dimensions deletes map tiles" do
      map = insert_autogenerated_dungeon()
      Repo.insert_all(Dungeon.SpawnLocation, [%{dungeon_id: map.id, row: 1, col: map.width-1},
                                              %{dungeon_id: map.id, row: map.height-1, col: 2},
                                              %{dungeon_id: map.id, row: 1, col: 1}])
      refute Dungeon.get_map_tile(map.id, map.width, map.height)
      assert Dungeon.get_map_tile(map.id, map.width-1, map.height-1)
      assert {:ok, _updated_map} = Dungeon.update_map(map, %{width: map.width - 1, height: map.height - 1})
      refute Dungeon.get_map_tile(map.id, map.width-1, map.height-1)
      assert [%{row: 1, col: 1}] = Repo.preload(map, :spawn_locations).spawn_locations
    end


    test "update_map/2 with invalid data returns error changeset" do
      map = map_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeon.update_map(map, @invalid_attrs)
      assert map == Dungeon.get_map!(map.id)
    end

    test "delete_map/1 deletes the map" do
      map = map_fixture()
      Repo.insert_all(Dungeon.SpawnLocation, [%{dungeon_id: map.id, row: 1, col: 1}, %{dungeon_id: map.id, row: 1, col: 2}])
      assert {:ok, map} = Dungeon.delete_map(map)
      assert %Map{} = map
      refute DungeonCrawl.Repo.get Dungeon.Map, map.id
    end

    test "delete_map!/1 deletes the map" do
      map = map_fixture()
      Repo.insert_all(Dungeon.SpawnLocation, [%{dungeon_id: map.id, row: 1, col: 1}, %{dungeon_id: map.id, row: 1, col: 2}])
      assert map = Dungeon.delete_map!(map)
      assert %Map{} = map
      refute DungeonCrawl.Repo.get Dungeon.Map, map.id
    end

    test "tile_template_reference_count/1 returns a count of the template being used" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      insert_stubbed_dungeon(%{},
        [Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                          Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
         Elixir.Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                          Elixir.Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
         Elixir.Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                          Elixir.Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])

      assert 2 == Dungeon.tile_template_reference_count(tile_a.id)
      assert 1 == Dungeon.tile_template_reference_count(tile_b)
    end

    test "change_map/1 returns a map changeset" do
      map = map_fixture()
      assert %Ecto.Changeset{} = Dungeon.change_map(map)
    end
  end

  describe "dungeon_map_tiles" do
    alias DungeonCrawl.Dungeon.MapTile

    @valid_attrs %{row: 15, col: 42}
    @invalid_attrs %{row: nil}

    def tile_template_fixture() do
      DungeonCrawl.TileTemplates.create_tile_template %{name: "X", description: "an x", character: "X"}
    end

    def map_tile_fixture(attrs \\ %{}, dungeon_id \\ nil) do
      {:ok, map} = if dungeon_id do
                     {:ok, Dungeon.get_map(dungeon_id)}
                   else
                     map_set = insert_map_set()
                     Dungeon.create_map(%{map_set_id: map_set.id, name: "test", width: 20, height: 20})
                   end
      {:ok, tile_template} = tile_template_fixture()
      {:ok, map_tile} =
        Elixir.Map.merge(%MapTile{}, @valid_attrs)
        |> Elixir.Map.merge(%{dungeon_id: map.id})
        |> Elixir.Map.merge(%{tile_template_id: tile_template.id})
        |> Elixir.Map.merge(attrs)
        |> Repo.insert()

      map_tile
    end

    test "list_dungeon_map_tiles/0 returns all dungeon_map_tiles" do
      map_tile = map_tile_fixture()
      assert Dungeon.list_dungeon_map_tiles() == [map_tile]
    end

    test "get_map_tile!/1 returns the map_tile with given id" do
      map_tile = map_tile_fixture()
      assert Dungeon.get_map_tile!(map_tile.id) == map_tile
    end

    test "get_map_tile!/1 returns the map tile with given map values (using the highest z_index)" do
      map_tile = map_tile_fixture(%{z_index: 1})
      lower_map_tile = map_tile_fixture(%{z_index: 0}, map_tile.dungeon_id)
      assert Dungeon.get_map_tile!(Map.take(lower_map_tile, [:dungeon_id, :row, :col])) == map_tile
    end

    test "get_map_tile!/1 returns the map tile with given map values" do
      map_tile = map_tile_fixture(%{z_index: 1})
      lower_map_tile = map_tile_fixture(%{z_index: 0}, map_tile.dungeon_id)
      assert Dungeon.get_map_tile!(Map.take(lower_map_tile, [:dungeon_id, :row, :col, :z_index])) == lower_map_tile
      assert Dungeon.get_map_tile!(Map.take(map_tile, [:dungeon_id, :row, :col, :z_index])) == map_tile
    end

    test "create_map_tile/1 with valid data creates a map_tile" do
      dungeon = insert_stubbed_dungeon()
      {:ok, tile_template} = tile_template_fixture()
      assert {:ok, %MapTile{} = _map_tile} = Dungeon.create_map_tile(Map.merge @valid_attrs, %{dungeon_id: dungeon.id, tile_template_id: tile_template.id})
    end

    test "create_map_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeon.create_map_tile(@invalid_attrs)
    end

   test "create_map_tile!/1 with valid data creates a map_tile" do
      dungeon = insert_stubbed_dungeon()
      {:ok, tile_template} = tile_template_fixture()
      assert %MapTile{} = Dungeon.create_map_tile!(Map.merge @valid_attrs, %{dungeon_id: dungeon.id, tile_template_id: tile_template.id})
    end

    test "update_map_tile/2 with valid data updates the map_tile" do
      map_tile = map_tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = map_tile.tile_template_id
      assert {:ok, map_tile} = Dungeon.update_map_tile(map_tile, %{tile_template_id: tile_template.id})
      assert %MapTile{} = map_tile
      refute old_tile_template == map_tile.tile_template_id
    end

    test "update_map_tile/2 with invalid data returns error changeset" do
      map_tile = map_tile_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeon.update_map_tile(map_tile, @invalid_attrs)
      assert map_tile == Dungeon.get_map_tile!(map_tile.id)
    end

    test "update_map_tile/1 with valid data updates the map_tile" do
      map_tile = map_tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = map_tile.tile_template_id
      assert {:ok, map_tile} = Dungeon.update_map_tile(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col},
                                                       %{tile_template_id: tile_template.id})
      assert %MapTile{} = map_tile
      refute old_tile_template == map_tile.tile_template_id
    end

    test "update_map_tile!/2 with valid data updates the map_tile" do
      map_tile = map_tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = map_tile.tile_template_id
      assert %MapTile{} = map_tile = Dungeon.update_map_tile!(map_tile, %{tile_template_id: tile_template.id})
      refute old_tile_template == map_tile.tile_template_id
    end

    test "update_map_tile!/1 with valid data updates the map_tile" do
      map_tile = map_tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = map_tile.tile_template_id
      assert %MapTile{} = map_tile = Dungeon.update_map_tile!(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col},
                                                              %{tile_template_id: tile_template.id})
      refute old_tile_template == map_tile.tile_template_id
    end

    test "change_map_tile/1 returns a map_tile changeset" do
      map_tile = map_tile_fixture()
      assert %Ecto.Changeset{} = Dungeon.change_map_tile(map_tile)
    end

    test "get_map_tile/1 returns a map_tile from the top" do
      bottom_tile = map_tile_fixture(%{z_index: 0})
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tile(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col}) == map_tile
      refute Dungeon.get_map_tile(%{dungeon_id: map_tile.dungeon_id+1, row: map_tile.row, col: map_tile.col})
    end

    test "get_map_tile/1 returns a map_tile for the coords including the top" do
      bottom_tile = map_tile_fixture(%{z_index: 0})
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tile(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col, z_index: 0}) == bottom_tile
      refute Dungeon.get_map_tile(%{dungeon_id: map_tile.dungeon_id+1, row: map_tile.row, col: map_tile.col})
    end

    test "get_map_tile/4 returns a map_tile with given z_index" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tile(map_tile.dungeon_id, map_tile.row, map_tile.col, 0) == bottom_tile
      refute Dungeon.get_map_tile(map_tile.dungeon_id, map_tile.row, map_tile.col, 0) == map_tile
      refute Dungeon.get_map_tile(map_tile.dungeon_id, map_tile.row, map_tile.col, 99)
    end

    test "get_map_tile/3 returns a map_tile with highest z_index" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tile(map_tile.dungeon_id, map_tile.row, map_tile.col) == map_tile
      refute Dungeon.get_map_tile(map_tile.dungeon_id + 1, map_tile.row, map_tile.col)
    end

    test "get_map_tiles/1 returns a map_tile from the top" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tiles(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col}) == [map_tile, bottom_tile]
      assert Dungeon.get_map_tiles(%{dungeon_id: map_tile.dungeon_id+1, row: map_tile.row, col: map_tile.col}) == []
    end

    test "get_map_tiles/3 returns a map_tile" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tiles(map_tile.dungeon_id, map_tile.row, map_tile.col) == [map_tile, bottom_tile]
      assert Dungeon.get_map_tiles(map_tile.dungeon_id + 1, map_tile.row, map_tile.col) == []
    end

    test "delete_map_tile/4 returns the deleted map_tile" do
      tile = map_tile_fixture()
      assert {:ok, deleted_tile} = Dungeon.delete_map_tile(tile.dungeon_id, tile.row, tile.col, tile.z_index)
      assert tile.id == deleted_tile.id
      refute Dungeon.get_map_tile(tile.dungeon_id, tile.row, tile.col, tile.z_index)
    end

    test "delete_map_tile/1 returns the deleted map_tile" do
      tile = map_tile_fixture()
      assert {:ok, deleted_tile} = Dungeon.delete_map_tile(tile)
      assert tile.id == deleted_tile.id
      refute Dungeon.get_map_tile(tile.dungeon_id, tile.row, tile.col, tile.z_index)
    end

    test "delete_map_tile/1 returns nil if given nil" do
      refute Dungeon.delete_map_tile(nil)
    end
  end

  describe "spawn_locations" do
    alias DungeonCrawl.Dungeon.SpawnLocation

    test "add_spawn_locations/2" do
      dungeon = insert_autogenerated_dungeon(%{height: 20, width: 20})
      assert {:ok, %{spawn_locations: {2, nil}}} = Dungeon.add_spawn_locations(dungeon.id, [{0,0}, {1,12}, {25, 3}, {0,0}, {0,50}])
      assert [{dungeon.id, 0, 0}, {dungeon.id, 1, 12}] ==
               _spawn_location_coords(Repo.preload(dungeon, :spawn_locations).spawn_locations)
      assert {:ok, %{spawn_locations: {1, nil}}} = Dungeon.add_spawn_locations(dungeon.id, [{1,12}, {8,8}])
      assert [{dungeon.id, 0, 0}, {dungeon.id, 1, 12}, {dungeon.id, 8,8}] ==
               _spawn_location_coords(Repo.preload(dungeon, :spawn_locations).spawn_locations)
    end

    test "clear_spawn_locations/1" do
      dungeon = insert_autogenerated_dungeon(%{height: 20, width: 20})
      Repo.insert_all(SpawnLocation, [%{dungeon_id: dungeon.id, row: 1, col: 0}, %{dungeon_id: dungeon.id, row: 1, col: 2}])
      assert Repo.preload(dungeon, :spawn_locations).spawn_locations != []
      Dungeon.clear_spawn_locations(dungeon.id)
      assert Repo.preload(dungeon, :spawn_locations).spawn_locations == []
    end

    test "set_spawn_locations/2" do
      dungeon = insert_autogenerated_dungeon()
      Repo.insert_all(SpawnLocation, [%{dungeon_id: dungeon.id, row: 1, col: 0}])
      assert [{dungeon.id, 1, 0}] ==
               _spawn_location_coords(Repo.preload(dungeon, :spawn_locations).spawn_locations)
      assert {:ok, %{spawn_locations: {1, nil}}} = Dungeon.set_spawn_locations(dungeon.id, [{8,8}])
      assert [{dungeon.id, 8, 8}] ==
               _spawn_location_coords(Repo.preload(dungeon, :spawn_locations).spawn_locations)
    end

    defp _spawn_location_coords(spawn_locations) do
      spawn_locations
      |> Enum.map(fn(sl) -> {sl.dungeon_id, sl.row, sl.col} end)
      |> Enum.sort
    end
  end
end

defmodule DungeonCrawl.DungeonsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonGeneration.MapGenerators.{TestRooms, ConnectedRooms, Labrynth, Empty, DrunkardsWalk}

  describe "dungeons" do
    alias DungeonCrawl.Dungeons.Level
    alias DungeonCrawl.Dungeons.Dungeon

    @valid_attrs %{name: "some content"}
    @valid_level_attrs %{height: 20, width: 20}
    @update_attrs %{name: "new name"}
    @invalid_attrs %{name: ""}

    def dungeon_fixture(attrs \\ %{}) do
      {:ok, dungeon} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Dungeons.create_dungeon()

      dungeon
    end

    test "list_dungeons/0 returns all dungeons" do
      dungeon = dungeon_fixture()
      assert Dungeons.list_dungeons() == [dungeon]
    end

    test "list_dungeons/1 returns all dungeons owned by the user" do
      dungeon_fixture()
      user = insert_user()
      dungeon = dungeon_fixture(%{user_id: user.id})
      assert Dungeons.list_dungeons(user) == [dungeon]
    end

    test "list_dungeons/1 returns all soft deleted dungeons" do
      dungeon_deleted = dungeon_fixture()
      dungeon_fixture()
      Dungeons.delete_dungeon(dungeon_deleted)
      assert Dungeons.list_dungeons(:soft_deleted) == [Dungeons.get_dungeon(dungeon_deleted.id)]
    end

    test "list_dungeons_with_player_count/0 returns all dungeons preloaded with the players in the level instances" do
      dungeon_fixture = dungeon_fixture()
      level = insert_autogenerated_level_instance(%{dungeon_id: dungeon_fixture.id})

      assert [%{dungeon_id: dungeon_id, dungeon: dungeon}] = Dungeons.list_dungeons_with_player_count()

      assert dungeon_id == dungeon_fixture.id
      assert Enum.count(dungeon.locations) == 0

      _p1 = insert_player_location(%{level_instance_id: level.id})
      _p2 = insert_player_location(%{level_instance_id: level.id, user_id_hash: "different"})

      assert [%{dungeon_id: dungeon_id, dungeon: dungeon}] = Dungeons.list_dungeons_with_player_count()

      assert dungeon_id == dungeon_fixture.id
      assert Enum.count(dungeon.locations) == 2
    end

    test "list_dungeons_by_lines/1 returns the most recent dungeons per line" do
      dungeon_fixture()
      user = insert_user()
      _dungeon_1a = dungeon_fixture(%{user_id: user.id, line_identifier: 1, version: 1, active: true})
      dungeon_1b = dungeon_fixture(%{user_id: user.id, line_identifier: 1, version: 2})
      dungeon_2 = dungeon_fixture(%{user_id: user.id, line_identifier: 2, version: 3, active: true})
      dungeon_3 = dungeon_fixture(%{user_id: user.id, line_identifier: 3, version: 2})
      assert Dungeons.list_dungeons_by_lines(user) == [dungeon_1b, dungeon_2, dungeon_3]
    end

    test "list_active_dungeons_with_player_count/0 returns all active dungeons preloaded with the players in the level instances" do
      insert_stubbed_dungeon_instance(%{active: false})
      insert_stubbed_dungeon_instance(%{active: true, deleted_at: NaiveDateTime.utc_now |> NaiveDateTime.truncate(:second)})

      di = insert_stubbed_dungeon_instance(%{active: true})
      level = Repo.preload(di, :levels).levels |> Enum.at(0)

      insert_player_location(%{level_instance_id: level.id})

      assert [%{dungeon_id: dungeon_id, dungeon: dungeon}] = Dungeons.list_active_dungeons_with_player_count()

      assert dungeon_id == di.dungeon_id
      assert Enum.count(dungeon.locations) == 1
    end

    test "instance_count/1 returns the number of instances existing for the dungeon" do
      assert Dungeons.instance_count(1) == 0

      di = insert_autogenerated_dungeon_instance(%{active: false})

      assert Dungeons.instance_count(di.dungeon_id) == 1
      assert Dungeons.instance_count(%Dungeon{id: di.dungeon_id}) == 1
    end

    test "get_dungeon!/1 returns the dungeon with given id" do
      dungeon = dungeon_fixture()
      assert dungeon == Dungeons.get_dungeon!(dungeon.id)
      assert dungeon == Dungeons.get_dungeon(dungeon.id)
    end

    test "get_dungeons/1 returns the different versions of the dungeon's line identifier" do
      dungeon = dungeon_fixture()
      dungeon2 = dungeon_fixture(%{version: 2, line_identifier: dungeon.line_identifier})
      dungeon_fixture(%{line_identifier: dungeon.id + 1})
      assert [dungeon2, dungeon] == Dungeons.get_dungeons(dungeon.line_identifier)
    end

    test "get_newest_dungeons_version/2 returns the latest version of the line identifier" do
      user = insert_user()
      dungeon_fixture(%{user_id: user.id})
      dungeon = dungeon_fixture(%{user_id: user.id})
      dungeon2 = dungeon_fixture(%{user_id: user.id, version: 2, line_identifier: dungeon.line_identifier})
      dungeon_fixture(%{user_id: user.id, line_identifier: dungeon.id + 1})
      assert dungeon2 == Dungeons.get_newest_dungeons_version(dungeon.line_identifier, user.id)
      refute Dungeons.get_newest_dungeons_version(dungeon.line_identifier, nil)
      refute Dungeons.get_newest_dungeons_version(nil, user.id)
      refute Dungeons.get_newest_dungeons_version(-1, -1)
    end

    test "get_title_level/1" do
      dungeon = dungeon_fixture()
      refute Dungeons.get_title_level(dungeon)
      level1 = insert_stubbed_level(%{dungeon_id: dungeon.id, number: 1})
      level2 = insert_stubbed_level(%{dungeon_id: dungeon.id, number: 2})
      assert Dungeons.get_title_level(dungeon).id == level1.id
      assert Dungeons.get_title_level(Map.put(dungeon, :title_number, level2.number)).id == level2.id
      refute Dungeons.get_title_level(Map.put(dungeon, :title_number, 0))
    end

    test "next_version_exists?/1 is true if the dungeon has a next version" do
      dungeon = insert_stubbed_dungeon()
      insert_stubbed_dungeon(%{previous_version_id: dungeon.id})
      assert Dungeons.next_version_exists?(dungeon)
    end

    test "next_version_exists?/1 is false if the dungeon does not have a next version" do
      dungeon = insert_stubbed_dungeon()
      refute Dungeons.next_version_exists?(dungeon)
    end

    test "copy_dungeon_fields/1" do
      dungeon = insert_stubbed_dungeon()
      assert %{autogenerated: false,
               default_map_height: nil,
               default_map_width: nil,
               name: "Autogenerated",
               state: nil,
               user_id: nil,
               line_identifier: dungeon.line_identifier,
               description: nil,
               title_number: nil} == Dungeons.copy_dungeon_fields(dungeon)
      assert %{} == Dungeons.copy_dungeon_fields(nil)
    end

    test "create_dungeon/1 with valid data creates a dungeon" do
      assert {:ok, %Dungeon{} = dungeon} = Dungeons.create_dungeon(@valid_attrs)
      assert dungeon.id == dungeon.line_identifier
    end

    test "create_dungeon/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeons.create_dungeon(@invalid_attrs)
    end

    test "create_new_dungeon_version/1 does not create a new version of an inactive dungeon" do
      dungeon = insert_stubbed_dungeon(%{active: false})
      assert {:error, "Inactive dungeon"} = Dungeons.create_new_dungeon_version(dungeon)
    end

    test "create_new_dungeon_version/1 does not create a new version if any levels have legacy dimensions which are now invalid" do
      dungeon = insert_stubbed_dungeon(%{active: true}, %{height: 40, width: 40})
      DungeonCrawl.Admin.update_setting(%{autogen_height: 20, autogen_width: 20, max_width: 20, max_height: 20})
      assert {:error, :new_levels, _, _} = Dungeons.create_new_dungeon_version(dungeon)
    end

    test "create_new_dungeon_version/1 creates a new version" do
      dungeon = insert_autogenerated_dungeon(%{active: true})
      level = Repo.preload(dungeon, :levels).levels |> Enum.at(0)
      Repo.insert_all(Dungeons.SpawnLocation, [%{level_id: level.id, row: 1, col: 1}, %{level_id: level.id, row: 1, col: 2}])
      assert {:ok, new_dungeon} = Dungeons.create_new_dungeon_version(dungeon)
      assert new_dungeon.version == dungeon.version + 1
      assert new_dungeon.line_identifier == dungeon.line_identifier

      assert %Dungeon{} = new_dungeon
      old_tiles = Repo.preload(level, :tiles).tiles
                  |> Enum.map(fn(t) -> Dungeons.copy_tile_fields(t) end)
                  |> Enum.sort
      old_spawn_locations = Repo.preload(level, :spawn_locations).spawn_locations
                            |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
      new_level = Repo.preload(new_dungeon, :levels).levels |> Enum.at(0)
      new_tiles = Repo.preload(new_level, :tiles).tiles
                  |> Enum.map(fn(t) -> Dungeons.copy_tile_fields(t) end)
                  |> Enum.sort
      new_spawn_locations = Repo.preload(new_level, :spawn_locations).spawn_locations
                            |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
      assert Map.drop(level, [:id, :dungeon_id, :inserted_at, :updated_at]) ==
             Map.drop(new_level, [:id, :dungeon_id, :inserted_at, :updated_at])
      assert old_tiles == new_tiles
      assert old_spawn_locations == new_spawn_locations
    end

    test "create_new_dungeon_version/1 does not create a new version if the next one exists" do
      dungeon = insert_stubbed_dungeon(%{active: true})
      insert_stubbed_dungeon(%{previous_version_id: dungeon.id})
      assert {:error, "New version already exists"} = Dungeons.create_new_dungeon_version(dungeon)
    end

    test "generate_dungeon/4 returns an autogenerated dungeon" do
      assert {:ok, %Dungeon{} = dungeon} = Dungeons.generate_dungeon(TestRooms, @valid_attrs, @valid_level_attrs)
      assert dungeon.autogenerated
      assert Enum.at(Repo.preload(dungeon, :levels).levels,0).entrance
    end

    test "generate_dungeon/4 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeons.generate_dungeon(TestRooms, @invalid_attrs)
      assert {:error, :level, %Ecto.Changeset{}, _others} = Dungeons.generate_dungeon(TestRooms, @valid_attrs)
    end

    test "generate_dungeon/4 returns a non autogenerated dungeon when fourth param is true" do
      assert {:ok, %Dungeon{} = dungeon} = Dungeons.generate_dungeon(TestRooms, @valid_attrs, @valid_level_attrs, true)
      refute dungeon.autogenerated
      assert Enum.at(Repo.preload(dungeon, :levels).levels,0).entrance
    end

    test "update_dungeon/2 with valid data updates the dungeon" do
      dungeon = dungeon_fixture()
      assert {:ok, dungeon} = Dungeons.update_dungeon(dungeon, @update_attrs)
      assert %Dungeon{} = dungeon
    end

    test "update_dungeon/2 with invalid data returns error changeset" do
      dungeon = dungeon_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeons.update_dungeon(dungeon, @invalid_attrs)
      assert dungeon == Dungeons.get_dungeon!(dungeon.id)
    end

    test "activate_dungeon/1 activtes the dungeon" do
      dungeon = dungeon_fixture()
      refute dungeon.active
      assert {:ok, activated_dungeon} = Dungeons.activate_dungeon(dungeon)
      assert activated_dungeon == Dungeons.get_dungeon(dungeon.id)
      assert activated_dungeon.active
    end

    test "activate_dungeon/1 soft deletes the previous version" do
      dungeon = dungeon_fixture()
      new_dungeon = dungeon_fixture(%{previous_version_id: dungeon.id})
      assert {:ok, activated_dungeon} = Dungeons.activate_dungeon(new_dungeon)
      assert Dungeons.get_dungeon(dungeon.id).deleted_at
      assert Dungeons.get_dungeon(new_dungeon.id).active
      assert new_dungeon.id == activated_dungeon.id
    end

    test "activate_dungeon/1 with dungeon that has inactive tiles returns error message" do
      tile_a = insert_tile_template(%{name: "ACT", active: true})
      tile_b = insert_tile_template(%{name: "INT", active: false})
      dungeon = insert_stubbed_dungeon(%{}, %{},
                  [[Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                              Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                    Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                              Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                    Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                              Map.take(tile_b, [:character, :color, :background_color, :state, :script]))]])

      assert {:error, error_msg} = Dungeons.activate_dungeon(dungeon)
      assert error_msg == "Inactive tiles: INT (id: #{tile_b.id}) 1 times"
    end

    test "delete_dungeon/1 soft deletes the dungeon" do
      dungeon = dungeon_fixture()
      assert {:ok, dungeon} = Dungeons.delete_dungeon(dungeon)
      assert %Dungeon{} = dungeon
      assert dungeon.deleted_at
    end

    test "hard_delete_dungeon!/1 deletes the dungeon" do
      dungeon = insert_stubbed_dungeon(%{active: true})
      level = Repo.preload(dungeon, :levels).levels |> Enum.at(0)
      Repo.insert_all(Dungeons.SpawnLocation, [%{level_id: level.id, row: 1, col: 1}, %{level_id: level.id, row: 1, col: 2}])
      assert dungeon = Dungeons.hard_delete_dungeon!(dungeon)
      assert %Dungeon{} = dungeon
      refute DungeonCrawl.Repo.get Dungeons.Dungeon, dungeon.id
    end

    test "change_dungeon/1 returns a dungeon changeset" do
      dungeon = dungeon_fixture()
      assert %Ecto.Changeset{} = Dungeons.change_dungeon(dungeon)
    end
  end

  describe "levels" do
    alias DungeonCrawl.Dungeons.Level
    alias DungeonCrawl.Dungeons.Dungeon

    @valid_attrs %{name: "some content", height: 40, width: 80}
    @update_attrs %{name: "new name"}
    @invalid_attrs %{height: 1}

    def level_fixture(attrs \\ %{})
    def level_fixture(%{dungeon_id: dungeon_id} = attrs) do
      {:ok, level} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:dungeon_id, dungeon_id)
        |> Dungeons.create_level()

      level
    end
    def level_fixture(attrs) do
      {:ok, dungeon} = Dungeons.create_dungeon(%{name: "dungeon"})
      level_fixture(Map.put(attrs, :dungeon_id, dungeon.id))
    end

    test "list_levels/0 returns all levels for a dungeon" do
      level = level_fixture()
      assert Dungeons.list_levels(%Dungeon{id: level.dungeon_id}) == [level]
    end

    test "list_levels_with_player_count/0 returns all levels preloaded with the players in the level instances" do
      level_i = insert_autogenerated_level_instance()
      insert_autogenerated_level_instance(%{dungeon_id: Repo.preload(level_i, :dungeon).dungeon.dungeon_id, number: 2})
      di = Repo.preload(level_i, :dungeon).dungeon

      assert [%{level_id: _level_id1, level: level1}, %{level_id: _level_id2, level: _level2}] =
               Dungeons.list_levels_with_player_count(%Dungeon{id: di.dungeon_id})

      assert level1.id == level_i.level_id
      assert Enum.count(Repo.preload(level_i, [level: :locations]).level.locations) == 0

      insert_player_location(%{level_instance_id: level_i.id})
      insert_player_location(%{level_instance_id: level_i.id, user_id_hash: "different"})

      assert [%{level_id: _level_id1, level: _level1}, %{level_id: _level_id2, level: _level2}] =
               Dungeons.list_levels_with_player_count(%Dungeon{id: di.dungeon_id})
      assert Enum.count(Repo.preload(level_i, [level: :locations]).level.locations) == 2
    end

    test "next_level_number/1" do
      level = level_fixture()
      dungeon_1 = Repo.preload(level, :dungeon).dungeon
      dungeon_2 = insert_dungeon()

      assert Dungeons.next_level_number(dungeon_1) == 2
      assert Dungeons.next_level_number(dungeon_2) == 1 # has no more levels
    end

    test "get_level!/1 returns the level with given id" do
      level = level_fixture()
      assert Dungeons.get_level!(level.id) == level
    end

    test "get_level/2 returns the level in the dungeon instance for that number" do
      level = level_fixture()
      assert Dungeons.get_level(level.dungeon_id, level.number) == level
      refute Dungeons.get_level(level.dungeon_id, 123)
    end

    test "get_bounding_z_indexes!/1 returns the level's lowest and highest z index for given id" do
      tile_a = insert_tile_template()
      level = insert_stubbed_level(%{},
                [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                           Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                 Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 2},
                           Map.take(tile_a, [:character, :color, :background_color, :state, :script]))])

      assert Dungeons.get_bounding_z_indexes(level.id) == {0,2}
      assert Dungeons.get_bounding_z_indexes(level) == {0,2}
    end

    test "list_historic_tile_templates/1 when no historic tiles returns an empty array" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      level = insert_stubbed_level(%{},
                [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                           Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                 Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                           Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                 Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                           Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])
      assert Dungeons.list_historic_tile_templates(level) == []
    end

    test "list_historic_tile_templates/1 returns array of distinct historic tile templates" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      level = insert_stubbed_level(%{},
                [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                           Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                 Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                           Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
                 Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                           Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])
      {:ok, tile_a} = DungeonCrawl.TileTemplates.delete_tile_template(tile_a)
      assert Dungeons.list_historic_tile_templates(level) == [tile_a]
    end

    test "copy_level_fields/1" do
      level = insert_stubbed_level()
      assert %{entrance: nil,
               height: 20,
               name: "Stubbed",
               number: 1,
               number_east: nil,
               number_north: nil,
               number_south: nil,
               number_west: nil,
               state: nil,
               width: 20} == Dungeons.copy_level_fields(level)
      assert %{} == Dungeons.copy_level_fields(nil)
    end

    test "create_level/1 with valid data creates a level" do
      assert {:ok, %Level{} = _level} = Dungeons.create_level(Map.put(@valid_attrs, :dungeon_id, insert_dungeon().id))
    end

    test "create_level/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeons.create_level(@invalid_attrs)
    end

    test "generate_level/2 returns an autogenerated level" do
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(TestRooms, Map.put(@valid_attrs, :dungeon_id, insert_dungeon().id))
    end

    test "generate_level/2 adds a floor under any non basic tile" do
      level_attrs = Map.put(@valid_attrs, :dungeon_id, insert_dungeon().id)
      assert {:ok, %{level: %Level{} = level}} = Dungeons.generate_level(TestRooms, level_attrs, true)
      assert [%{character: "♂", name: "Bomb", z_index: 1},
              %{character: ".", name: "Floor", z_index: 0}] =
             Enum.sort(Dungeons.get_tiles(level.id, 2, 5), fn a, b -> a.z_index > b.z_index end)

    end

    test "generate_level/2 with invalid data returns error changeset" do
      assert {:error, :level, %Ecto.Changeset{}, _others} = Dungeons.generate_level(TestRooms, @invalid_attrs)
    end

    test "generate_level/2 with the various generators for solo and dungeon editing" do
      attrs = fn -> Map.put(@valid_attrs, :dungeon_id, insert_dungeon().id) end
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(ConnectedRooms, attrs.())
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(ConnectedRooms, attrs.(), 1)
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(Labrynth, attrs.())
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(Labrynth, attrs.(), 1)
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(Empty, attrs.())
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(Empty, attrs.(), 1)
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(DrunkardsWalk, attrs.())
      assert {:ok, %{level: %Level{} = _level}} = Dungeons.generate_level(DrunkardsWalk, attrs.(), 1)
    end

    test "update_level/2 with valid data updates the level" do
      level = level_fixture()
      assert {:ok, level} = Dungeons.update_level(level, @update_attrs)
      assert %Level{} = level
    end

    test "update_level/2 with bigger dimensions creates new emtpy tiles" do
      level = insert_autogenerated_level()
      refute Dungeons.get_tile(level.id, level.width, level.height)
      assert {:ok, _updated_level} = Dungeons.update_level(level, %{width: level.width + 1, height: level.height + 1})
      assert Dungeons.get_tile(level.id, level.width, level.height).tile_template_id
    end

    test "update_level/2 with smaller dimensions deletes tiles" do
      level = insert_autogenerated_level()
      Repo.insert_all(Dungeons.SpawnLocation, [%{level_id: level.id, row: 1, col: level.width-1},
                                              %{level_id: level.id, row: level.height-1, col: 2},
                                              %{level_id: level.id, row: 1, col: 1}])
      refute Dungeons.get_tile(level.id, level.width, level.height)
      assert Dungeons.get_tile(level.id, level.width-1, level.height-1)
      assert {:ok, _updated_level} = Dungeons.update_level(level, %{width: level.width - 1, height: level.height - 1})
      refute Dungeons.get_tile(level.id, level.width-1, level.height-1)
      assert [%{row: 1, col: 1}] = Repo.preload(level, :spawn_locations).spawn_locations
    end


    test "update_level/2 with invalid data returns error changeset" do
      level = level_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeons.update_level(level, @invalid_attrs)
      assert level == Dungeons.get_level!(level.id)
    end

    test "delete_level/1 deletes the level" do
      level = level_fixture()
      Repo.insert_all(Dungeons.SpawnLocation, [%{level_id: level.id, row: 1, col: 1}, %{level_id: level.id, row: 1, col: 2}])
      assert {:ok, level} = Dungeons.delete_level(level)
      assert %Level{} = level
      refute DungeonCrawl.Repo.get Dungeons.Level, level.id
    end

    test "link_unlinked_levels/1 links adjacent levels if they are not already linked" do
      level_1 = level_fixture(%{number: 1, number_north: 2, number_west: 3})
      level_2 = level_fixture(%{number: 2, dungeon_id: level_1.dungeon_id, number_south: 3})
      level_3 = level_fixture(%{number: 3, dungeon_id: level_1.dungeon_id})

      assert Dungeons.link_unlinked_levels(level_1)

      assert %{number_north:   2, number_south: nil, number_east: nil, number_west:   3} = Dungeons.get_level(level_1.id)
      assert %{number_north: nil, number_south:   3, number_east: nil, number_west: nil} = Dungeons.get_level(level_2.id)
      assert %{number_north: nil, number_south: nil, number_east:   1, number_west: nil} = Dungeons.get_level(level_3.id)
    end

    test "delete_level!/1 deletes the level" do
      level = level_fixture()
      Repo.insert_all(Dungeons.SpawnLocation, [%{level_id: level.id, row: 1, col: 1}, %{level_id: level.id, row: 1, col: 2}])
      assert level = Dungeons.delete_level!(level)
      assert %Level{} = level
      refute DungeonCrawl.Repo.get Dungeons.Level, level.id
    end

    test "tile_template_reference_count/1 returns a count of the template being used" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      insert_stubbed_level(%{},
        [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                   Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
         Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                   Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
         Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0},
                   Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])

      assert 2 == Dungeons.tile_template_reference_count(tile_a.id)
      assert 1 == Dungeons.tile_template_reference_count(tile_b)
    end

    test "change_level/1 returns a level changeset" do
      level = level_fixture()
      assert %Ecto.Changeset{} = Dungeons.change_level(level)
    end

    test "adjacent_level_names/1" do
      level_1 = level_fixture(%{number: 1, number_north: 2, number_west: 3})
      _level_2 = level_fixture(%{number: 2, dungeon_id: level_1.dungeon_id, number_south: 3})
      _level_3 = level_fixture(%{number: 3, dungeon_id: level_1.dungeon_id, name: "Number Three"})

      assert %{ north: "2 - some content",
                south: nil,
                east: nil,
                west: "3 - Number Three"} == Dungeons.adjacent_level_names(level_1)
    end

    test "adjacent_level_edge_tiles/1" do
      level_1 = level_fixture(%{number: 1, number_east: 2, number_south: 2, number_west: 2})
      _level_2 = insert_autogenerated_level(%{number: 2, dungeon_id: level_1.dungeon_id})

      assert %{north: nil,
               south: southern_edge_tiles,
               west: western_edge_tiles,
               east: eastern_edge_tiles} = Dungeons.adjacent_level_edge_tiles(level_1)
      assert length(southern_edge_tiles) == 21
      assert length(western_edge_tiles) == 21
      assert length(eastern_edge_tiles) == 21

      [ actual_list_south, actual_list_west, actual_list_east] = \
        [southern_edge_tiles, western_edge_tiles, eastern_edge_tiles]
        |> Enum.map(fn tiles -> tiles
                                |> Enum.map(fn tile -> Map.take(tile, [:row, :col, :character]) end)
                                |> Enum.sort(fn a,b -> {a.row, a.col} < {b.row, b.col} end)
                    end)

      # this is what the test room generator generates, hardcoded basically
      expected_list_south = Enum.map(0..16, fn i -> %{row: 0, col: i, character: "#"} end) ++
                            Enum.map(17..20, fn i -> %{row: 0, col: i, character: " "} end)
      expected_list_west = Enum.map(0..20, fn i -> %{row: i, col: 20, character: " "} end)
      expected_list_east = Enum.map(0..4, fn i -> %{row: i, col: 0, character: "#"} end) ++
                           Enum.map(5..20, fn i -> %{row: i, col: 0, character: " "} end)
      assert expected_list_south == actual_list_south
      assert expected_list_west == actual_list_west
      assert expected_list_east == actual_list_east
    end

    test "adjacent_level_edge_tile/2" do
      level_1 = level_fixture(%{number: 1, number_north: 2})
      _level_2 = insert_autogenerated_level(%{number: 2, dungeon_id: level_1.dungeon_id})

      assert %{north: northern_edge_tiles} = Dungeons.adjacent_level_edge_tile(level_1, "north")

      actual_list_north = Enum.map(northern_edge_tiles, fn tile -> Map.take(tile, [:row, :col, :character]) end)
                          |> Enum.sort(fn a,b -> {a.row, a.col} < {b.row, b.col} end)

      expected_list_north = Enum.map(0..20, fn i -> %{row: 20, col: i, character: " "} end)
      assert expected_list_north == actual_list_north
    end

    test "level_edge_tiles/3" do
      level_1 = level_fixture(%{number: 1, number_north: 2})
      level_2 = insert_autogenerated_level(%{number: 2, dungeon_id: level_1.dungeon_id})

      assert northern_edge_tiles = Dungeons.level_edge_tiles(level_2, "south")

      actual_list_north = Enum.map(northern_edge_tiles, fn tile -> Map.take(tile, [:row, :col, :character]) end)
                          |> Enum.sort(fn a,b -> {a.row, a.col} < {b.row, b.col} end)

      expected_list_north = Enum.map(0..20, fn i -> %{row: 20, col: i, character: " "} end)
      assert expected_list_north == actual_list_north

      # Bad input
      refute Dungeons.level_edge_tiles(nil, "north")
      refute Dungeons.level_edge_tiles(level_1, nil)

      # other attributes selected, nilling out other attrs not selected
      expected = Enum.map(0..20, fn _ -> %{character: " ", row: nil, col: nil} end)
      actual = Dungeons.level_edge_tiles(level_2, "south", [:character])
               |> Enum.map(fn t -> Map.take(t, [:character, :row, :col]) end)
      assert length(expected) == length(actual)
      assert ^expected = actual
    end
  end

  describe "tiles" do
    alias DungeonCrawl.Dungeons.Tile

    @valid_attrs %{row: 15, col: 42}
    @invalid_attrs %{row: nil}

    def tile_template_fixture() do
      DungeonCrawl.TileTemplates.create_tile_template %{name: "X", description: "an x", character: "X"}
    end

    def tile_fixture(attrs \\ %{}, level_id \\ nil) do
      {:ok, level} = if level_id do
                       {:ok, Dungeons.get_level(level_id)}
                     else
                       dungeon = insert_dungeon()
                       Dungeons.create_level(%{dungeon_id: dungeon.id, name: "test", width: 20, height: 20})
                     end
      {:ok, tile_template} = tile_template_fixture()
      {:ok, tile} =
        Map.merge(%Tile{}, @valid_attrs)
        |> Map.merge(%{level_id: level.id})
        |> Map.merge(%{tile_template_id: tile_template.id})
        |> Map.merge(attrs)
        |> Repo.insert()

      tile
    end

    test "get_tile!/1 returns the tile with given id" do
      tile = tile_fixture()
      assert Dungeons.get_tile!(tile.id) == tile
    end

    test "get_tile!/1 returns the tile with given coordinates (using the highest z_index)" do
      tile = tile_fixture(%{z_index: 1})
      lower_tile = tile_fixture(%{z_index: 0}, tile.level_id)
      assert Dungeons.get_tile!(Map.take(lower_tile, [:level_id, :row, :col])) == tile
    end

    test "get_tile!/1 returns the tile with given coordinates" do
      tile = tile_fixture(%{z_index: 1})
      lower_tile = tile_fixture(%{z_index: 0}, tile.level_id)
      assert Dungeons.get_tile!(Map.take(lower_tile, [:level_id, :row, :col, :z_index])) == lower_tile
      assert Dungeons.get_tile!(Map.take(tile, [:level_id, :row, :col, :z_index])) == tile
    end

    test "copy_tile_fields/1" do
      tile = tile_fixture()
      assert %{animate_background_colors: nil,
               animate_characters: nil,
               animate_colors: nil,
               animate_period: nil,
               animate_random: nil,
               background_color: nil,
               character: nil,
               col: 42,
               color: nil,
               name: nil,
               row: 15,
               script: "",
               state: nil,
               tile_template_id: tile.tile_template_id,
               z_index: 0} == Dungeons.copy_tile_fields(tile)
      assert %{} == Dungeons.copy_tile_fields(nil)
    end

    test "create_tile/1 with valid data creates a tile" do
      level = insert_stubbed_level()
      {:ok, tile_template} = tile_template_fixture()
      assert {:ok, %Tile{} = _tile} = Dungeons.create_tile(Map.merge @valid_attrs, %{level_id: level.id, tile_template_id: tile_template.id})
    end

    test "create_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeons.create_tile(@invalid_attrs)
    end

   test "create_tile!/1 with valid data creates a tile" do
      level = insert_stubbed_level()
      {:ok, tile_template} = tile_template_fixture()
      assert %Tile{} = Dungeons.create_tile!(Map.merge @valid_attrs, %{level_id: level.id, tile_template_id: tile_template.id})
    end

    test "update_tile/2 with valid data updates the tile" do
      tile = tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = tile.tile_template_id
      assert {:ok, tile} = Dungeons.update_tile(tile, %{tile_template_id: tile_template.id})
      assert %Tile{} = tile
      refute old_tile_template == tile.tile_template_id
    end

    test "update_tile/2 with invalid data returns error changeset" do
      tile = tile_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeons.update_tile(tile, @invalid_attrs)
      assert tile == Dungeons.get_tile!(tile.id)
    end

    test "update_tile/1 with valid data updates the tile" do
      tile = tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = tile.tile_template_id
      assert {:ok, tile} = Dungeons.update_tile(%{level_id: tile.level_id, row: tile.row, col: tile.col},
                                                       %{tile_template_id: tile_template.id})
      assert %Tile{} = tile
      refute old_tile_template == tile.tile_template_id
    end

    test "update_tile!/2 with valid data updates the tile" do
      tile = tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = tile.tile_template_id
      assert %Tile{} = tile = Dungeons.update_tile!(tile, %{tile_template_id: tile_template.id})
      refute old_tile_template == tile.tile_template_id
    end

    test "update_tile!/1 with valid data updates the tile" do
      tile = tile_fixture()
      {:ok, tile_template} = tile_template_fixture()
      old_tile_template = tile.tile_template_id
      assert %Tile{} = tile = Dungeons.update_tile!(%{level_id: tile.level_id, row: tile.row, col: tile.col},
                                                    %{tile_template_id: tile_template.id})
      refute old_tile_template == tile.tile_template_id
    end

    test "change_tile/1 returns a tile changeset" do
      tile = tile_fixture()
      assert %Ecto.Changeset{} = Dungeons.change_tile(tile)
    end

    test "get_tile/1 returns a tile from the top" do
      bottom_tile = tile_fixture(%{z_index: 0})
      tile = tile_fixture(%{z_index: 1}, bottom_tile.level_id)
      assert Dungeons.get_tile(%{level_id: tile.level_id, row: tile.row, col: tile.col}) == tile
      refute Dungeons.get_tile(%{level_id: tile.level_id+1, row: tile.row, col: tile.col})
    end

    test "get_tile/1 returns a tile for the coords including the top" do
      bottom_tile = tile_fixture(%{z_index: 0})
      tile = tile_fixture(%{z_index: 1}, bottom_tile.level_id)
      assert Dungeons.get_tile(%{level_id: tile.level_id, row: tile.row, col: tile.col, z_index: 0}) == bottom_tile
      refute Dungeons.get_tile(%{level_id: tile.level_id+1, row: tile.row, col: tile.col})
    end

    test "get_tile/4 returns a tile with given z_index" do
      bottom_tile = tile_fixture()
      tile = tile_fixture(%{z_index: 1}, bottom_tile.level_id)
      assert Dungeons.get_tile(tile.level_id, tile.row, tile.col, 0) == bottom_tile
      refute Dungeons.get_tile(tile.level_id, tile.row, tile.col, 0) == tile
      refute Dungeons.get_tile(tile.level_id, tile.row, tile.col, 99)
    end

    test "get_tile/3 returns a tile with highest z_index" do
      bottom_tile = tile_fixture()
      tile = tile_fixture(%{z_index: 1}, bottom_tile.level_id)
      assert Dungeons.get_tile(tile.level_id, tile.row, tile.col) == tile
      refute Dungeons.get_tile(tile.level_id + 1, tile.row, tile.col)
    end

    test "get_tiles/1 returns a tile from the top" do
      bottom_tile = tile_fixture()
      tile = tile_fixture(%{z_index: 1}, bottom_tile.level_id)
      assert Dungeons.get_tiles(%{level_id: tile.level_id, row: tile.row, col: tile.col}) == [tile, bottom_tile]
      assert Dungeons.get_tiles(%{level_id: tile.level_id+1, row: tile.row, col: tile.col}) == []
    end

    test "get_tiles/3 returns a tile" do
      bottom_tile = tile_fixture()
      tile = tile_fixture(%{z_index: 1}, bottom_tile.level_id)
      assert Dungeons.get_tiles(tile.level_id, tile.row, tile.col) == [tile, bottom_tile]
      assert Dungeons.get_tiles(tile.level_id + 1, tile.row, tile.col) == []
    end

    test "delete_tile/4 returns the deleted tile" do
      tile = tile_fixture()
      assert {:ok, deleted_tile} = Dungeons.delete_tile(tile.level_id, tile.row, tile.col, tile.z_index)
      assert tile.id == deleted_tile.id
      refute Dungeons.get_tile(tile.level_id, tile.row, tile.col, tile.z_index)
    end

    test "delete_tile/1 returns the deleted tile" do
      tile = tile_fixture()
      assert {:ok, deleted_tile} = Dungeons.delete_tile(tile)
      assert tile.id == deleted_tile.id
      refute Dungeons.get_tile(tile.level_id, tile.row, tile.col, tile.z_index)
    end

    test "delete_tile/1 returns nil if given nil" do
      refute Dungeons.delete_tile(nil)
    end
  end

  describe "spawn_locations" do
    alias DungeonCrawl.Dungeons.SpawnLocation

    test "add_spawn_locations/2" do
      level = insert_autogenerated_level(%{height: 20, width: 20})
      assert {:ok, %{spawn_locations: {2, nil}}} = Dungeons.add_spawn_locations(level.id, [{0,0}, {1,12}, {25, 3}, {0,0}, {0,50}])
      assert [{level.id, 0, 0}, {level.id, 1, 12}] ==
               _spawn_location_coords(Repo.preload(level, :spawn_locations).spawn_locations)
      assert {:ok, %{spawn_locations: {1, nil}}} = Dungeons.add_spawn_locations(level.id, [{1,12}, {8,8}])
      assert [{level.id, 0, 0}, {level.id, 1, 12}, {level.id, 8,8}] ==
               _spawn_location_coords(Repo.preload(level, :spawn_locations).spawn_locations)
    end

    test "clear_spawn_locations/1" do
      level = insert_autogenerated_level(%{height: 20, width: 20})
      Repo.insert_all(SpawnLocation, [%{level_id: level.id, row: 1, col: 0}, %{level_id: level.id, row: 1, col: 2}])
      assert Repo.preload(level, :spawn_locations).spawn_locations != []
      Dungeons.clear_spawn_locations(level.id)
      assert Repo.preload(level, :spawn_locations).spawn_locations == []
    end

    test "set_spawn_locations/2" do
      level = insert_autogenerated_level()
      Repo.insert_all(SpawnLocation, [%{level_id: level.id, row: 1, col: 0}])
      assert [{level.id, 1, 0}] ==
               _spawn_location_coords(Repo.preload(level, :spawn_locations).spawn_locations)
      assert {:ok, %{spawn_locations: {1, nil}}} = Dungeons.set_spawn_locations(level.id, [{8,8}])
      assert [{level.id, 8, 8}] ==
               _spawn_location_coords(Repo.preload(level, :spawn_locations).spawn_locations)
    end

    defp _spawn_location_coords(spawn_locations) do
      spawn_locations
      |> Enum.map(fn(sl) -> {sl.level_id, sl.row, sl.col} end)
      |> Enum.sort
    end
  end
end

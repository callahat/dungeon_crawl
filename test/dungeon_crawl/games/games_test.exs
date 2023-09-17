defmodule DungeonCrawl.GamesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.Tile
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Tile, as: TileInstance
  alias DungeonCrawl.Games
  alias DungeonCrawl.Player
  alias DungeonCrawl.Player.Location

  import DungeonCrawlWeb.TestHelpers

  describe "saved_games" do
    alias DungeonCrawl.Games.Save

    import DungeonCrawl.GamesFixtures

    @invalid_attrs %{col: nil, row: nil, state: nil, user_id_hash: nil}

    test "list_saved_games/0 returns all saved_games" do
      save = save_fixture()
      assert Games.list_saved_games() == [save]
    end

    test "list_saved_games/1 returns all saved_games for given user id hash and dungeon id" do
      save1 = save_fixture(%{user_id_hash: "one"})
      save_fixture(%{user_id_hash: "one"})
      save_fixture()
      dungeon_id = Repo.preload(save1, :dungeon_instance).dungeon_instance.dungeon_id
      assert Games.list_saved_games(%{user_id_hash: "one", dungeon_id: dungeon_id}) == [save1]
      assert Games.list_saved_games(%{user_id_hash: "derp", dungeon_id: dungeon_id}) == []
    end

    test "list_saved_games/1 returns all saved_games for given dungeon id" do
      save1 = save_fixture(%{user_id_hash: "one"})
      save_fixture(%{user_id_hash: "one"})
      dungeon_id = Repo.preload(save1, :dungeon_instance).dungeon_instance.dungeon_id
      assert Games.list_saved_games(%{dungeon_id: dungeon_id}) == [save1]
    end

    test "list_saved_games/1 returns all saved_games for given user id hash" do
      save1 = save_fixture(%{user_id_hash: "one"})
      save2 = save_fixture(%{user_id_hash: "one"})
      save3 = save_fixture()
      assert Games.list_saved_games(%{user_id_hash: "one"}) == [save1, save2]
      assert Games.list_saved_games(%{user_id_hash: save3.user_id_hash}) == [save3]
      assert Games.list_saved_games(%{user_id_hash: "derp"}) == []
    end

    test "has_saved_games?/1" do
      save = save_fixture(%{user_id_hash: "one"})
             |> Repo.preload(:dungeon_instance)
      assert Games.has_saved_games?(save.level_instance)
      assert Games.has_saved_games?(save.dungeon_instance)
      assert Games.has_saved_games?(save.dungeon_instance.id)
      refute Games.has_saved_games?(save.dungeon_instance.id + 1)
    end

    test "get_save/1 returns the save with given id" do
      save = save_fixture()
      assert Games.get_save(save.id) == save
    end

    test "get_save/2 returns the save with the given id and user_id_hash" do
      save = save_fixture()
      assert Games.get_save(save.id, save.user_id_hash) == save
      refute Games.get_save(save.id, "someone else")
    end

    test "create_save/1 with valid data creates a save" do
      level_instance = insert_autogenerated_level_instance()
      location = insert_player_location(%{level_instance_id: level_instance.id})

      valid_attrs = %{col: 42, row: 42, state: %{valid: "state"}, user_id_hash: "some user_id_hash",
        level_instance_id: level_instance.id, location_id: location.id, host_name: "Bob",
        level_name: "1 - test", player_location_id: location.id}

      assert {:ok, %Save{} = save} = Games.create_save(valid_attrs)
      assert save.col == 42
      assert save.row == 42
      assert save.state == %{valid: "state"}
      assert save.user_id_hash == "some user_id_hash"
      assert save.host_name == "Bob"
      assert save.level_name == "1 - test"
    end

    test "create_save/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Games.create_save(@invalid_attrs)
    end

    test "update_save/2 with valid data updates the save" do
      save = save_fixture()
      update_attrs = %{col: 43, row: 43, state: %{some: "updated state"}, user_id_hash: "some updated user_id_hash",
        player_location_id: DungeonCrawl.Player.create_location!(%{user_id_hash: "some updated user_id_hash"}).id}

      assert {:ok, %Save{} = save} = Games.update_save(save, update_attrs)
      assert save.col == 43
      assert save.row == 43
      assert save.state == %{some: "updated state"}
      assert save.user_id_hash == "some updated user_id_hash"
    end

    test "update_save/2 with invalid data returns error changeset" do
      save = save_fixture()
      assert {:error, %Ecto.Changeset{}} = Games.update_save(save, @invalid_attrs)
      assert save == Games.get_save(save.id)
    end

    test "load_save/2 invalid save id returns error" do
      user = insert_user()
      assert {:error, "Save not found"} = Games.load_save(1, user.user_id_hash)
    end

    test "load_save/2 nonexistant user" do
      save = save_fixture(%{user_id_hash: "junk"})
      assert {:error, "Player not found"} = Games.load_save(save.id, "junk")
    end

    test "load_save/2 invalid user" do
      user = insert_user()
      save = save_fixture(%{user_id_hash: "junk"})
      assert {:error, "Save does not belong to player"} = Games.load_save(save.id, user.user_id_hash)
    end

    test "load_save/2 creates the tile instance and sets it on the player location" do
      user = insert_user()
      save = save_fixture(%{user_id_hash: user.user_id_hash})

      refute Player.get_location(user.user_id_hash)

      assert {:ok, %Location{}} = Games.load_save(save.id, user.user_id_hash)
      assert location = Player.get_location(user.user_id_hash)
      assert %{background_color: "whitesmoke",
               character: "@",
               col: 42,
               color: "black",
               name: "Some User",
               row: 42,
               script: "",
               state: %{player: true},
               z_index: 100
             } = DungeonCrawl.Repo.preload(location, :tile).tile
      assert location.id == save.player_location_id

      # won't load a game when already crawling
      assert {:error, "Player already in a game"} = Games.load_save(save.id, user.user_id_hash)
    end

    test "convert_save/1 when its dungeon is still active" do
      save = save_fixture()
      refute Games.convert_save(save)
    end

    test "convert_save/1" do
      # Setup
      old_dungeon = insert_stubbed_dungeon(%{active: true}, %{},
      [
        [
          %Tile{character: "?", row: 1, col: 3, name: "Wall", state: %{blocking: true}, script: "#end\n:touch\nHi"},
          %Tile{character: ".", row: 2, col: 3, name: "dot", script: "/s"},
          %Tile{character: "-", row: 3, col: 3, name: "dash", state: %{blocking: true}},
        ],
        [
          %Tile{character: "+", row: 1, col: 1, name: "Door", state: %{blocking: true}},
          %Tile{character: ".", row: 2, col: 1, name: "Floor"},
          %Tile{character: "#", row: 3, col: 1, name: "Wall", state: %{blocking: true}},
        ]
      ])
      [_level_1, level_2_solo] = Repo.preload(old_dungeon, :levels).levels
      {:ok, _level_2_solo} = DungeonCrawl.Dungeons.update_level(level_2_solo, %{state: %{solo: true}})

      insert_user(%{user_id_hash: "one", name: "Player One"})
      insert_user(%{user_id_hash: "two", name: "Player Two"})

      player_1 = insert_player_location(%{user_id_hash: "one", tile_instance_id: nil})
      player_2 = insert_player_location(%{user_id_hash: "two", tile_instance_id: nil})

      {:ok, %{dungeon: old_di}} = DungeonCrawl.DungeonInstances.create_dungeon(old_dungeon, "test", false, true)
      [old_header_1, old_header_2] = Repo.preload(old_di, :level_headers).level_headers
      level_instance_1 = DungeonCrawl.DungeonInstances.find_or_create_level(old_header_1, player_1.id)
      level_instance_2a = DungeonCrawl.DungeonInstances.find_or_create_level(old_header_2, player_1.id)
      level_instance_2b = DungeonCrawl.DungeonInstances.find_or_create_level(old_header_2, player_2.id)

      tile_1_a = DungeonInstances.get_tile(level_instance_1.id, 1, 3)
      _tile_1_b = DungeonInstances.get_tile(level_instance_1.id, 2, 3)
      tile_1_c = DungeonInstances.get_tile(level_instance_1.id, 3, 3)

      tile_2a_a = DungeonInstances.get_tile(level_instance_2a.id, 1, 1)
      tile_2a_b = DungeonInstances.get_tile(level_instance_2a.id, 2, 1)
      _tile_2a_c = DungeonInstances.get_tile(level_instance_2a.id, 3, 1)

      _tile_2b_a = DungeonInstances.get_tile(level_instance_2b.id, 1, 1)
      _tile_2b_b = DungeonInstances.get_tile(level_instance_2b.id, 2, 1)
      _tile_2b_c = DungeonInstances.get_tile(level_instance_2b.id, 3, 1)

      tile_1_a_moved = Repo.update!(TileInstance.changeset(tile_1_a, %{col: 1}))
      tile_2a_a_changed = Repo.update!(TileInstance.changeset(tile_2a_a, %{character: "'", state: %{blocking: false}}))
      tile_2b_d_created = Repo.insert!(TileInstance.changeset(%TileInstance{}, %{level_instance_id: level_instance_2b.id, character: "N", row: 6, col: 3}))

      {:ok, save_1} =
        %{user_id_hash: player_1.user_id_hash,
          player_location_id: player_1.id,
          host_name: old_di.host_name,
          level_name: "Level 1"}
        |> Map.merge(%{level_instance_id: level_instance_1.id, row: 2, col: 3, z_index: 3, state: %{player: true}})
        |> Games.create_save()

      {:ok, save_2} =
        %{user_id_hash: player_2.user_id_hash,
          player_location_id: player_2.id,
          host_name: old_di.host_name,
          level_name: "Level 2"}
        |> Map.merge(%{level_instance_id: level_instance_2b.id, row: 2, col: 3, z_index: 3, state: %{player: true}})
        |> Games.create_save()

      # New dungeon version
      {:ok, new_dungeon} = Dungeons.create_new_dungeon_version(old_dungeon)

      [new_level_1, new_level_2_solo] = Repo.preload(new_dungeon, :levels).levels

      _new_tile_1_a = Dungeons.get_tile(new_level_1.id, 1, 3)
      new_tile_1_b = Dungeons.get_tile(new_level_1.id, 2, 3)
      _new_tile_1_c = Dungeons.get_tile(new_level_1.id, 3, 3)

      new_tile_2_c = Dungeons.get_tile(new_level_2_solo.id, 3, 1)

      # Base dungeon updates for the new version
      new_tile_1_a_created = Repo.insert!(Tile.changeset(%Tile{}, %{level_id: new_level_1.id, character: "1", row: 3, col: 3, z_index: 2}))
      new_tile_1_b_changed = Repo.update!(Tile.changeset(new_tile_1_b, %{character: ",", state: %{flag: true}}))
      _new_tile_2_c_deleted = Repo.delete!(new_tile_2_c)
      new_tile_2_d_created = Repo.insert!(Tile.changeset(%Tile{}, %{level_id: new_level_2_solo.id, character: "$", row: 2, col: 1, z_index: 2}))

      {:ok, new_dungeon} = Dungeons.update_dungeon(new_dungeon, %{state: %{testing: 123}})
      {:ok, _new_level_2_solo} = Dungeons.update_level(new_level_2_solo, %{state: %{solo: true, waffle: "blue-berry"}})

      {:ok, _new_dungeon} = Dungeons.activate_dungeon(new_dungeon)

      # --------------------------------------------------------------------------------------------
      # Test when converting it as a personal instance
      converted_save_1 = Games.convert_save(save_1)
                         |> Repo.preload([:dungeon, :dungeon_instance])
      converted_save_2 = Games.convert_save(save_2)
                         |> Repo.preload([:dungeon, :dungeon_instance])

      assert Map.drop(converted_save_1, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon]) ==
               Map.drop(save_1, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon])
      assert Map.drop(converted_save_2, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon]) ==
               Map.drop(save_2, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon])

      refute converted_save_1.dungeon_instance.id == converted_save_2.dungeon_instance.id
      assert converted_save_1.dungeon.id == converted_save_2.dungeon.id

      new_di_1 = converted_save_1.dungeon_instance
      new_di_2 = converted_save_2.dungeon_instance

      new_level_instance_1a = DungeonCrawl.DungeonInstances.get_level(new_di_1.id, 1)
                             |> Repo.preload(:tiles)
      new_level_instance_1b = DungeonCrawl.DungeonInstances.get_level(new_di_2.id, 1)
                             |> Repo.preload(:tiles)
      new_level_instance_2a = DungeonCrawl.DungeonInstances.get_level(new_di_1.id, 2, player_1.id)
                              |> Repo.preload(:tiles)
      new_level_instance_2b = DungeonCrawl.DungeonInstances.get_level(new_di_2.id, 2, player_2.id)
                              |> Repo.preload(:tiles)

      assert normalized_tiles([new_tile_1_a_created, tile_1_a_moved, new_tile_1_b_changed, tile_1_c]) ==
               normalized_tiles(new_level_instance_1a.tiles)
      assert normalized_tiles([tile_2a_a_changed, tile_2a_b, new_tile_2_d_created]) ==
               normalized_tiles(new_level_instance_2a.tiles)

      assert normalized_tiles([new_tile_1_a_created, tile_1_a_moved, new_tile_1_b_changed, tile_1_c]) ==
               normalized_tiles(new_level_instance_1b.tiles)
      assert normalized_tiles([tile_2a_a, tile_2a_b, new_tile_2_d_created, tile_2b_d_created]) ==
               normalized_tiles(new_level_instance_2b.tiles)

      # Cleanup
      Games.update_save(converted_save_1, %{level_instance_id: level_instance_1.id})
      Games.update_save(converted_save_2, %{level_instance_id: level_instance_2b.id})

      DungeonInstances.delete_dungeon(converted_save_1.dungeon_instance)
      DungeonInstances.delete_dungeon(converted_save_2.dungeon_instance)

      refute DungeonInstances.get_dungeon(converted_save_1.dungeon_instance.id)
      refute DungeonInstances.get_dungeon(converted_save_2.dungeon_instance.id)

      # --------------------------------------------------------------------------------------------
      # Test when converting it as a public instance, such as when a dungeon creator
      # creates a new version and wants to move all saves to it.
      converted_save_1 = Games.convert_save(save_1, false)
                         |> Repo.preload([:dungeon, :dungeon_instance])
      converted_save_2 = Games.convert_save(save_2, false)
                         |> Repo.preload([:dungeon, :dungeon_instance])

      assert Map.drop(converted_save_1, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon]) ==
               Map.drop(save_1, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon])
      assert Map.drop(converted_save_2, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon]) ==
               Map.drop(save_2, [:level_instance_id, :updated_at, :level_instance, :dungeon_instance, :dungeon])

      new_di_id = converted_save_1.dungeon_instance.id

      assert new_di_id == converted_save_2.dungeon_instance.id
      assert converted_save_1.dungeon.id == converted_save_2.dungeon.id

      new_level_instance_1 = DungeonCrawl.DungeonInstances.get_level(new_di_id, 1)
                              |> Repo.preload(:tiles)
      new_level_instance_2a = DungeonCrawl.DungeonInstances.get_level(new_di_id, 2, player_1.id)
                              |> Repo.preload(:tiles)
      new_level_instance_2b = DungeonCrawl.DungeonInstances.get_level(new_di_id, 2, player_2.id)
                              |> Repo.preload(:tiles)

      assert normalized_tiles([new_tile_1_a_created, tile_1_a_moved, new_tile_1_b_changed, tile_1_c]) ==
               normalized_tiles(new_level_instance_1.tiles)
      assert normalized_tiles([tile_2a_a_changed, tile_2a_b, new_tile_2_d_created]) ==
               normalized_tiles(new_level_instance_2a.tiles)
      assert normalized_tiles([tile_2a_a, tile_2a_b, new_tile_2_d_created, tile_2b_d_created]) ==
               normalized_tiles(new_level_instance_2b.tiles)
    end

    defp normalized_tiles(tiles) do
      Enum.map(tiles, fn tile -> Dungeons.copy_tile_fields(tile) |> Map.delete(:tile_template_id) end)
      |> Enum.sort(fn tile_a, tile_b ->
        {tile_a.row, tile_a.col, tile_a.z_index} < {tile_b.row, tile_b.col, tile_b.z_index}
      end)
    end

    test "convert_saves/1 when invalid" do
      inactive_dungeon = insert_stubbed_dungeon(%{active: false})
      deleted_dungeon = insert_stubbed_dungeon(%{active: true, deleted_at: DateTime.utc_now()})

      assert Games.convert_saves(inactive_dungeon) == :error
      assert Games.convert_saves(deleted_dungeon) == :error
    end

    test "convert_saves/1" do
      # Setup
      dungeon_v1 = insert_stubbed_dungeon(%{active: true}, %{}, [[], []])

      [_level_1, level_2_solo] = Repo.preload(dungeon_v1, :levels).levels
      {:ok, _level_2_solo} = DungeonCrawl.Dungeons.update_level(level_2_solo, %{state: %{solo: true}})

      {:ok, dungeon_v2} = Dungeons.create_new_dungeon_version(dungeon_v1)
      {:ok, dungeon_v2} = Dungeons.activate_dungeon(dungeon_v2)

      {:ok, dungeon_v3} = Dungeons.create_new_dungeon_version(dungeon_v2)
      {:ok, dungeon_v3} = Dungeons.activate_dungeon(dungeon_v3)

      insert_user(%{user_id_hash: "one", name: "Player One"})
      insert_user(%{user_id_hash: "two", name: "Player Two"})
      insert_user(%{user_id_hash: "three", name: "Player Three"})

      player_1 = insert_player_location(%{user_id_hash: "one", tile_instance_id: nil})
      player_2 = insert_player_location(%{user_id_hash: "two", tile_instance_id: nil})
      player_3 = insert_player_location(%{user_id_hash: "three", tile_instance_id: nil})

      {:ok, %{dungeon: di_v1}} = DungeonCrawl.DungeonInstances.create_dungeon(dungeon_v1, "test", false, true)
      [v1_old_header_1, _v1_old_header_2] = Repo.preload(di_v1, :level_headers).level_headers
      v1_level_instance_1 = DungeonCrawl.DungeonInstances.find_or_create_level(v1_old_header_1, player_1.id)

      {:ok, save_1} =
        %{user_id_hash: player_1.user_id_hash,
          player_location_id: player_1.id,
          host_name: di_v1.host_name,
          level_name: "Level 1"}
        |> Map.merge(%{level_instance_id: v1_level_instance_1.id, row: 2, col: 3, z_index: 3, state: %{player: true}})
        |> Games.create_save()

      {:ok, %{dungeon: di_v2}} = DungeonCrawl.DungeonInstances.create_dungeon(dungeon_v2, "test", false, true)
      [v2_header_1, v2_header_2] = Repo.preload(di_v2, :level_headers).level_headers

      v2_level_instance_1 = DungeonCrawl.DungeonInstances.find_or_create_level(v2_header_1, player_2.id)
      v2_level_instance_2a = DungeonCrawl.DungeonInstances.find_or_create_level(v2_header_2, player_2.id)
      _v2_level_instance_2b = DungeonCrawl.DungeonInstances.find_or_create_level(v2_header_2, player_3.id)

      {:ok, save_2} =
        %{user_id_hash: player_2.user_id_hash,
          player_location_id: player_2.id,
          host_name: di_v2.host_name,
          level_name: "Level 2"}
        |> Map.merge(%{level_instance_id: v2_level_instance_2a.id, row: 2, col: 3, z_index: 3, state: %{player: true}})
        |> Games.create_save()

      {:ok, save_3} =
        %{user_id_hash: player_3.user_id_hash,
          player_location_id: player_3.id,
          host_name: di_v2.host_name,
          level_name: "Level 2"}
        |> Map.merge(%{level_instance_id: v2_level_instance_1.id, row: 2, col: 3, z_index: 3, state: %{player: true}})
        |> Games.create_save()

      # -------------------------------------------------------------------------------
      # Testing
      assert Games.convert_saves(dungeon_v3) == :ok

      assert 3 == Repo.all(Games.Save) |> Enum.count()

      [di_v3] = Repo.preload(dungeon_v3, :dungeon_instances).dungeon_instances

      save_2_new_lid = DungeonCrawl.DungeonInstances.get_level(di_v3.id, 2, player_2.id).id
      save_3_new_lid = DungeonCrawl.DungeonInstances.get_level(di_v3.id, 1).id

      assert save_1 == Games.get_save(save_1.id)
      assert %{save_2 | level_instance_id: save_2_new_lid} == Games.get_save(save_2.id)
      assert %{save_3 | level_instance_id: save_3_new_lid} == Games.get_save(save_3.id)
    end

    test "delete_save/1 deletes the save" do
      save = save_fixture()
      assert {:ok, %Save{}} = Games.delete_save(save)
      refute Games.get_save(save.id)
      refute Repo.get(Location, save.player_location_id)
    end

    test "delete_save/1 deletes the save but keeps the location if it has a tile" do
      level_instance = insert_autogenerated_level_instance()
      player_loc = insert_player_location(%{level_instance_id: level_instance.id})
      save = save_fixture(%{player_location_id: player_loc.id})
      assert {:ok, %Save{}} = Games.delete_save(save)
      refute Games.get_save(save.id)
      assert Repo.get(Location, save.player_location_id)
    end

    test "change_save/1 returns a save changeset" do
      save = save_fixture()
      assert %Ecto.Changeset{} = Games.change_save(save)
    end
  end
end

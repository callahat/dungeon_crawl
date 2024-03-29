defmodule DungeonCrawl.DungeonInstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances

  describe "dungeon_instances" do
    alias DungeonCrawl.DungeonInstances.{Dungeon, Level, LevelHeader}

    test "get_dungeon!/1 returns the dungeon with given id" do
      di = insert_stubbed_dungeon_instance()
      assert %Dungeon{} = DungeonInstances.get_dungeon(di.id)
      assert DungeonInstances.get_dungeon(di.id) == di
      assert DungeonInstances.get_dungeon!(di.id) == di
      refute DungeonInstances.get_dungeon(di.id + 1)
    end

    test "create_dungeon/1" do
      dungeon = insert_autogenerated_dungeon(%{}, %{number: 2, number_north: 1, number_south: 4})
      level = Repo.preload(dungeon, :levels).levels |> Enum.at(0)

      assert {:ok, %{dungeon: di = %Dungeon{}, levels: [instance]}} = DungeonInstances.create_dungeon(dungeon, "chillbro")
      assert Map.take(dungeon, [:name, :autogenerated, :state]) == Map.take(di, [:name, :autogenerated, :state])
      assert "chillbro" == di.host_name
      assert Map.take(instance, [:name, :width, :height, :state, :number, :entrance,
                                 :number_north, :number_south, :number_east, :number_west,
                                 :animate_random, :animate_period, :animate_characters, :animate_colors, :animate_background_colors]) ==
             Map.take(level, [:name, :width, :height, :state, :number, :entrance,
                              :number_north, :number_south, :number_east, :number_west,
                              :animate_random, :animate_period, :animate_characters, :animate_colors, :animate_background_colors])
      assert _tile_details(level) == _tile_details(instance)
      assert di.passcode =~ ~r/^\w{8}$/
    end

    test "create_dungeon/2 can create a private instance" do
      dungeon = insert_autogenerated_dungeon(%{}, %{number: 2, number_north: 1, number_south: 4})

      assert {:ok, %{dungeon: di = %Dungeon{}, levels: [instance]}} = DungeonInstances.create_dungeon(dungeon, "chillbro", true)

      assert di.passcode =~ ~r/^\w{8}$/
      assert di.is_private
      assert %Level{} = instance
    end

    test "create_dungeon/3 can create a dungeon instance with only level headers" do
      dungeon = insert_autogenerated_dungeon(%{}, %{number: 2, number_north: 1, number_south: 4})

      assert {:ok, %{dungeon: di = %Dungeon{}, levels: [header]}} = DungeonInstances.create_dungeon(dungeon, "chillbro", false, true)

      refute di.is_private
      assert %LevelHeader{number: 2} = header
      assert Repo.preload(header, :levels).levels == []
    end

    test "update_dungeon/2 when given the dungeon" do
      dungeon_instance = insert_stubbed_dungeon_instance(%{state: %{"flag" => false}})

      assert {:ok, updated_instance} =
               DungeonInstances.update_dungeon(
                 dungeon_instance,
                 %{state: %{"flag" => true, "a" => "b"}})
      assert updated_instance.state == %{"flag" => true, "a" => "b"}
      assert Map.delete(updated_instance, :state) ==
               Map.delete(dungeon_instance, :state)
    end

    test "update_dungeon/2 when given the level instance id" do
      dungeon_instance = insert_stubbed_dungeon_instance(%{state: %{"flag" => false}})

      assert {:ok, updated_instance} =
               DungeonInstances.update_dungeon(
                 dungeon_instance.id,
                 %{state: %{"flag" => true, "a" => "b"}})
      assert updated_instance.state == %{"flag" => true, "a" => "b"}
      assert Map.delete(updated_instance, :state) ==
               Map.delete(dungeon_instance, :state)
    end

    test "update_dungeon/2 when dungeon not found" do
      refute DungeonInstances.update_dungeon(nil, %{number_north: 2})
    end

    test "delete_dungeon/1" do
      dungeon = insert_stubbed_dungeon_instance(%{active: true})
      level = Repo.preload(dungeon, :levels).levels |> Enum.at(0)
      assert dungeon = DungeonInstances.delete_dungeon(dungeon)
      assert %Dungeon{} = dungeon
      refute DungeonCrawl.Repo.get Dungeon, dungeon.id
      refute DungeonCrawl.Repo.get DungeonInstances.Level, level.id
    end
  end

  describe "level_instances" do
    alias DungeonCrawl.DungeonInstances.{Dungeon, Level, LevelHeader, Tile}

    test "get_level!/1 returns the level with given id" do
      instance = insert_stubbed_level_instance()
      assert DungeonInstances.get_level(instance.id) == instance
      assert DungeonInstances.get_level!(instance.id) == instance
    end

    test "get_level/2 returns the level in the level instance for that number" do
      instance = insert_stubbed_level_instance()
      assert DungeonInstances.get_level(instance.dungeon_instance_id, instance.number) == instance
      refute DungeonInstances.get_level(instance.dungeon_instance_id, 123)
      refute DungeonInstances.get_level(instance.dungeon_instance_id, nil)
    end

    test "get_level/3 returns the level in the level instance for that number owned by that player location" do
      location = DungeonCrawl.Player.create_location!(%{user_id_hash: "goodhash"})
      instance = insert_autogenerated_level_instance(%{player_location_id: location.id})
      assert DungeonInstances.get_level(instance.dungeon_instance_id, instance.number, location.id) == instance
      refute DungeonInstances.get_level(instance.dungeon_instance_id, 123, location.id)
      refute DungeonInstances.get_level(instance.dungeon_instance_id, instance.number, location.id + 1)
    end

    test "get_adjacent_levels/1" do
      di = insert_autogenerated_dungeon_instance()
      instance = Repo.preload(di, [:levels]).levels |> Enum.at(0)
      instance = Repo.update!(Level.changeset(instance, %{number_north: instance.number, number_south: instance.number}))

      assert %{"north" => instance.number, "south" => instance.number, "east" => nil, "west" => nil} ==
        DungeonInstances.get_adjacent_levels(instance.id)
    end

    test "create_level_header/2 copies a level to a new instance" do
      dungeon = insert_autogenerated_dungeon()
      dungeon_attrs = Map.merge(%{dungeon_id: dungeon.id, is_private: false}, Map.take(dungeon, [:name, :autogenerated, :state]))
      dungeon_instance = Dungeon.changeset(%Dungeon{}, dungeon_attrs)
                         |> Repo.insert!

      level = Repo.preload(dungeon, :levels).levels |> Enum.at(0)

      assert {:ok, level_header} = DungeonInstances.create_level_header(level, dungeon_instance.id)
      assert %{level_id: level.id, number: level.number, dungeon_instance_id: dungeon_instance.id} ==
        %{level_id: level_header.level_id, number: level_header.number, dungeon_instance_id: level_header.dungeon_instance_id}
    end

    test "create_level/3 copies a level to a new instance" do
      di = insert_autogenerated_dungeon_instance(%{headers_only: true})
      level = Repo.preload(di, [dungeon: :levels]).dungeon.levels |> Enum.at(0)
      lh = Repo.preload(di, :level_headers).level_headers |> Enum.at(0)

      assert {:ok, %{level: instance = %Level{}}} = DungeonInstances.create_level(Map.put(level, :number, 2), lh.id, di.id)
      assert Map.take(instance, [:name, :width, :height]) == Map.take(level, [:name, :width, :height])
      assert _tile_details(level) == _tile_details(instance)
    end

    test "get_level_header/2" do
      di = insert_autogenerated_dungeon_instance()
      level_header = Repo.preload(di, :level_headers).level_headers |> Enum.at(0)
      assert level_header == DungeonInstances.get_level_header(di.id, level_header.number)
    end

    test "find_or_create_level/2 when its a universal level instance" do
      di = insert_autogenerated_dungeon_instance(%{headers_only: true}, %{type: :universal})
      location = DungeonCrawl.Player.create_location!(%{user_id_hash: "goodhash"})
      level_header = Repo.preload(di, :level_headers).level_headers |> Enum.at(0)

      refute DungeonInstances.get_level(di.id, level_header.number)
      assert %Level{} = level = DungeonInstances.find_or_create_level(level_header, location.id)
      assert DungeonInstances.get_level(di.id, level_header.number)
      # finds the level instance that already exists
      assert level == DungeonInstances.find_or_create_level(level_header, location.id)
    end

    test "find_or_create_level/2 when its a solo level instance" do
      di = insert_autogenerated_dungeon_instance(%{headers_only: true}, %{type: :solo})
      # the determination of solo or univeral will be something else, this is just a stub
      Repo.preload(di, :level_headers).level_headers
      |> Enum.at(0)
      |> LevelHeader.changeset(%{type: :solo})
      |> Repo.update!
      location = DungeonCrawl.Player.create_location!(%{user_id_hash: "goodhash"})
      other_location = DungeonCrawl.Player.create_location!(%{user_id_hash: "other"})
      level_header = Repo.preload(di, :level_headers).level_headers |> Enum.at(0)

      refute DungeonInstances.get_level(di.id, level_header.number)
      refute DungeonInstances.get_level(di.id, level_header.number, location.id)
      refute DungeonInstances.get_level(di.id, level_header.number, other_location.id)
      assert %Level{} = level = DungeonInstances.find_or_create_level(level_header, location.id)
      refute DungeonInstances.get_level(di.id, level_header.number)
      assert DungeonInstances.get_level(di.id, level_header.number, location.id)
      # finds the level instance that already exists
      assert level == DungeonInstances.find_or_create_level(level_header, location.id)
      # creates for other location
      assert %Level{} = other_level = DungeonInstances.find_or_create_level(level_header, other_location.id)
      assert level != other_level
      assert level.player_location_id == location.id
      assert Map.take(level, [:name, :width, :height]) == Map.take(other_level, [:name, :width, :height])
      assert _tile_details(level) == _tile_details(other_level)
    end

    test "find_or_create_level/2 with a nil header" do
      refute DungeonInstances.find_or_create_level(nil, 69420)
    end

    test "update_level/2 when given the level" do
      level_instance = insert_stubbed_level_instance(%{state: "flag: false"}, [
        %Tile{character: "?", row: 1, col: 3, state: "blocking: true", script: "#end\n:touch\nHi"}
      ])

      level_instance = %{ level_instance | passage_exits: [{123, "gold"}, {9, "gamma"}] }

      assert {:ok, updated_instance} =
               DungeonInstances.update_level(
                 level_instance,
                 %{passage_exits: [{123, "gold"}, {9, "gamma"}]})
      assert updated_instance.passage_exits == [{123, "gold"}, {9, "gamma"}]
      assert Map.delete(updated_instance, :passage_exits) ==
               Map.delete(level_instance, :passage_exits)
    end

    test "update_level/2 when given the level instance id" do
      level_instance = insert_stubbed_level_instance(%{state: "flag: false"}, [
        %Tile{character: "?", row: 1, col: 3, state: "blocking: true", script: "#end\n:touch\nHi"}
      ])

      level_instance = %{ level_instance | passage_exits: [{123, "gold"}, {9, "gamma"}] }

      assert {:ok, updated_instance} =
               DungeonInstances.update_level(
                 level_instance.id,
                 %{passage_exits: [{123, "gold"}, {9, "gamma"}]})
      assert updated_instance.passage_exits == [{123, "gold"}, {9, "gamma"}]
      assert Map.delete(updated_instance, :passage_exits) ==
               Map.delete(level_instance, :passage_exits)
    end

    test "update_level/2 when level not found" do
      refute DungeonInstances.update_level(nil, %{number_north: 2})
    end

    test "delete_level/1 deletes a level instance" do
      di = insert_autogenerated_dungeon_instance(%{headers_only: true})
      level = Repo.preload(di, [dungeon: :levels]).dungeon.levels |> Enum.at(0)
      lh = Repo.preload(di, :level_headers).level_headers |> Enum.at(0)
      {:ok, %{level: instance = %Level{}}} = DungeonInstances.create_level(Map.put(level, :number, 2), lh.id, di.id)

      assert {:ok, %Level{}} = DungeonInstances.delete_level(instance)
      assert_raise Ecto.NoResultsError, fn -> DungeonInstances.get_level!(instance.id) end
    end

    test "delete_level!/1 deletes a level instance" do
      di = insert_autogenerated_dungeon_instance(%{headers_only: true})
      level = Repo.preload(di, [dungeon: :levels]).dungeon.levels |> Enum.at(0)
      lh = Repo.preload(di, :level_headers).level_headers |> Enum.at(0)
      {:ok, %{level: instance = %Level{}}} = DungeonInstances.create_level(Map.put(level, :number, 2), lh.id, di.id)

      assert %Level{} = DungeonInstances.delete_level!(instance)
      assert_raise Ecto.NoResultsError, fn -> DungeonInstances.get_level!(instance.id) end
    end

    test "tile_difference_from_base/1" do
      level_instance = insert_stubbed_level_instance(%{}, [
        %Tile{character: "?", row: 1, col: 3, name: "Wall", state: "blocking: true", script: "#end\n:touch\nHi"},
        %Tile{character: ".", row: 2, col: 3, name: "dot", script: "/s"},
        %Tile{character: "-", row: 3, col: 3, name: "dash", state: "blocking: true"},
        %Tile{character: "x", row: 4, col: 3},
        %Tile{character: "y", row: 5, col: 3, name: "Wall"}
      ])

      tile_a = DungeonInstances.get_tile(level_instance.id, 1, 3)
      _tile_b = DungeonInstances.get_tile(level_instance.id, 2, 3)
      tile_c = DungeonInstances.get_tile(level_instance.id, 3, 3)
      _tile_d = DungeonInstances.get_tile(level_instance.id, 4, 3)
      _tile_e = DungeonInstances.get_tile(level_instance.id, 5, 3)

      tile_a_moved = Repo.update!(Tile.changeset(tile_a, %{col: 1}))
      tile_c_changed = Repo.update!(Tile.changeset(tile_c, %{state: "blocking: false"}))
      tile_f_created = Repo.insert!(Tile.changeset(%Tile{}, %{level_instance_id: level_instance.id, character: "N", row: 6, col: 3}))

      base_tile_a = Map.take(tile_a, [:row, :col, :z_index])
                    |> Map.put(:level_id, level_instance.level_id)
                    |> DungeonCrawl.Dungeons.get_tile!()
      base_tile_c = Map.take(tile_c, [:row, :col, :z_index])
                    |> Map.put(:level_id, level_instance.level_id)
                    |> DungeonCrawl.Dungeons.get_tile!()

      assert [new_tiles, deleted_tiles] = DungeonInstances.tile_difference_from_base(level_instance)
      assert [tile_a_moved, tile_c_changed, tile_f_created] == Enum.sort(new_tiles, fn a,b -> a.id < b.id end)
      assert [base_tile_a, base_tile_c] ==
               Enum.sort(deleted_tiles, fn a,b -> a.id < b.id end)
    end

    test "tile_difference/2" do
      level_instance_base = insert_stubbed_level_instance(%{}, [
        %Tile{character: "?", row: 1, col: 3, name: "Wall", state: "blocking: true", script: "#end\n:touch\nHi"},
        %Tile{character: ".", row: 2, col: 3, name: "dot", script: "/s"},
        %Tile{character: "-", row: 3, col: 3, name: "dash", state: "blocking: true"},
      ]) |> Repo.preload(:level)

      tile_a_base = DungeonInstances.get_tile(level_instance_base.id, 1, 3)

      level_instance_updated = insert_stubbed_level_instance(%{}, [
        %Tile{character: "?", row: 1, col: 1, name: "Wall", state: "blocking: true", script: "#end\n:touch\nHi"},
        %Tile{character: "!", row: 2, col: 3, name: "dot", script: "/s"},
        %Tile{character: "-", row: 3, col: 3, name: "dash", state: "blocking: true"},
        %Tile{character: "x", row: 4, col: 3},
      ])

      tile_a_updated = DungeonInstances.get_tile(level_instance_updated.id, 1, 1)
      tile_d_updated = DungeonInstances.get_tile(level_instance_updated.id, 4, 3)

      assert [new_tiles, deleted_tiles] = DungeonInstances.tile_difference(level_instance_updated, level_instance_base)
      assert [tile_a_updated, tile_d_updated] == Enum.sort(new_tiles, fn a,b -> a.id < b.id end)
      assert [tile_a_base] == deleted_tiles


      tile_a_base_level = Map.take(tile_a_base, [:row, :col, :z_index])
                    |> Map.put(:level_id, level_instance_base.level_id)
                    |> DungeonCrawl.Dungeons.get_tile!()

      assert [new_tiles, deleted_tiles] = DungeonInstances.tile_difference(level_instance_updated, level_instance_base.level)
      assert [tile_a_updated, tile_d_updated] == Enum.sort(new_tiles, fn a,b -> a.id < b.id end)
      assert [tile_a_base_level] == deleted_tiles
    end
  end

  describe "tile_instances" do
    alias DungeonCrawl.DungeonInstances.Tile

    @valid_attrs %{row: 15, col: 42}
    @invalid_attrs %{row: nil}

    def tile_fixture(attrs \\ %{}, level_instance_id \\ nil) do
      instance = if level_instance_id do
                   Repo.get!(DungeonInstances.Level, level_instance_id)
                 else
                   insert_stubbed_level_instance()
                 end

      tile_template = insert_tile_template()
      {:ok, tile} =
        Map.merge(%Tile{}, @valid_attrs)
        |> Map.merge(%{level_instance_id: instance.id})
        |> Map.merge(%{tile_template_id: tile_template.id})
        |> Map.merge(attrs)
        |> Repo.insert()

      tile
    end

    test "get_tile/3 populated Tile struct" do
      tile = Map.delete(tile_fixture(), :tile_template_id)
      assert ^tile = DungeonInstances.get_tile(tile.level_instance_id, tile.row, tile.col)
    end

    test "get_tile/4 populated Tile struct" do
      tile = Map.delete(tile_fixture(), :tile_template_id)
      assert ^tile = DungeonInstances.get_tile(tile.level_instance_id, tile.row, tile.col, tile.z_index)
    end

    test "get_tile_by_id/1" do
      tile = Map.delete(tile_fixture(), :tile_template_id)
      assert ^tile = DungeonInstances.get_tile_by_id(tile.id)
    end

    test "new_tile/1 with valid data returns a populated Tile struct" do
      other_tile = tile_fixture()
      assert {:ok, %Tile{id: nil} = _tile} = DungeonInstances.new_tile(Map.merge @valid_attrs, Map.take(other_tile, [:level_instance_id, :tile_template_id]))
    end

    test "new_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DungeonInstances.new_tile(@invalid_attrs)
    end

    test "create_tile/1 with valid data creates a tile" do
      other_tile = tile_fixture()
      assert {:ok, %Tile{} = _tile} = DungeonInstances.create_tile(Map.merge @valid_attrs, Map.take(other_tile, [:level_instance_id, :tile_template_id]))
    end

    test "create_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DungeonInstances.create_tile(@invalid_attrs)
    end

    test "update_tiles/1 updates valid changes" do
      tile_1 = tile_fixture(%{character: "0"})
      {:ok, tile_2} = DungeonInstances.create_tile(Map.merge @valid_attrs, Map.take(tile_1, [:character, :level_instance_id, :tile_template_id]))

      good_changeset = Tile.changeset(tile_1, %{character: "Y"})
      bad_changeset = Tile.changeset(tile_2, %{character: "XXX", color: "red"})

      assert {:ok, %{tile_updates: 2}} = DungeonInstances.update_tiles([good_changeset, bad_changeset])
      assert "Y" == Repo.get(Tile, tile_1.id).character
      refute "XXX" == Repo.get(Tile, tile_2.id).character
    end

    test "delete_tiles/1 deletes the tiles with given ids" do
      tile_1 = tile_fixture(%{character: "0"})
      {:ok, tile_2} = DungeonInstances.create_tile(Map.merge @valid_attrs, Map.take(tile_1, [:character, :level_instance_id, :tile_template_id]))

      assert {1, nil} = DungeonInstances.delete_tiles([tile_1.id])
      refute Repo.get(Tile, tile_1.id)
      assert Repo.get(Tile, tile_2.id)
    end
  end

  # Utility methods
  defp _tile_details(level) do
    Repo.preload(level, :tiles).tiles
    |> Enum.map(fn(mt) -> Map.take(mt, [:row, :col, :z_index, :character, :color, :background_color, :state, :script]) end)
    |> Enum.sort
  end
end

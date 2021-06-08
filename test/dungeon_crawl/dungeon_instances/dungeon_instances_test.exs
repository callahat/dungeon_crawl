defmodule DungeonCrawl.DungeonInstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances

  describe "dungeon_instances" do
    alias DungeonCrawl.DungeonInstances.Dungeon

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

      assert {:ok, %{dungeon: di = %Dungeon{}, levels: [instance]}} = DungeonInstances.create_dungeon(dungeon)
      assert Map.take(dungeon, [:name, :autogenerated, :state]) == Map.take(di, [:name, :autogenerated, :state])
      assert Map.take(instance, [:name, :width, :height, :state, :number, :entrance,
                                 :number_north, :number_south, :number_east, :number_west,
                                 :animate_random, :animate_period, :animate_characters, :animate_colors, :animate_background_colors]) ==
             Map.take(level, [:name, :width, :height, :state, :number, :entrance,
                              :number_north, :number_south, :number_east, :number_west,
                              :animate_random, :animate_period, :animate_characters, :animate_colors, :animate_background_colors])
      assert _tile_details(level) == _tile_details(instance)
      assert di.passcode =~ ~r/^\w{8}$/
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
    alias DungeonCrawl.DungeonInstances.Level

    test "get_level!/1 returns the level with given id" do
      instance = insert_stubbed_level_instance()
      assert DungeonInstances.get_level(instance.id) == instance
      assert DungeonInstances.get_level!(instance.id) == instance
    end

    test "get_level/2 returns the level in the level set instance for that number" do
      instance = insert_stubbed_level_instance()
      assert DungeonInstances.get_level(instance.dungeon_instance_id, instance.number) == instance
      refute DungeonInstances.get_level(instance.dungeon_instance_id, 123)
    end

    test "get_adjacent_levels/1" do
      di = insert_autogenerated_dungeon_instance()
      instance = Repo.preload(di, [:levels]).levels |> Enum.at(0)
      instance = Repo.update!(Level.changeset(instance, %{number_north: instance.number, number_south: instance.number}))

      assert %{"north" => instance, "south" => instance, "east" => %{id: nil}, "west" => %{id: nil}} ==
        DungeonInstances.get_adjacent_levels(instance.id)
    end

    test "create_level/1 copies a level to a new instance" do
      di = insert_autogenerated_dungeon_instance()
      level = Repo.preload(di, [dungeon: :levels]).dungeon.levels |> Enum.at(0)

      assert {:ok, %{level: instance = %Level{}}} = DungeonInstances.create_level(Map.put(level, :number, 2), di.id)
      assert Map.take(instance, [:name, :width, :height]) == Map.take(level, [:name, :width, :height])
      assert _tile_details(level) == _tile_details(instance)
    end

    test "delete_level/1 deletes a level instance" do
      di = insert_autogenerated_dungeon_instance()
      level = Repo.preload(di, [dungeon: :levels]).dungeon.levels |> Enum.at(0)
      {:ok, %{level: instance = %Level{}}} = DungeonInstances.create_level(Map.put(level, :number, 2), di.id)

      assert {:ok, %Level{}} = DungeonInstances.delete_level(instance)
      assert_raise Ecto.NoResultsError, fn -> DungeonInstances.get_level!(instance.id) end
    end

    test "delete_level!/1 deletes a level instance" do
      di = insert_autogenerated_dungeon_instance()
      level = Repo.preload(di, [dungeon: :levels]).dungeon.levels |> Enum.at(0)
      {:ok, %{level: instance = %Level{}}} = DungeonInstances.create_level(Map.put(level, :number, 2), di.id)

      assert %Level{} = DungeonInstances.delete_level!(instance)
      assert_raise Ecto.NoResultsError, fn -> DungeonInstances.get_level!(instance.id) end
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

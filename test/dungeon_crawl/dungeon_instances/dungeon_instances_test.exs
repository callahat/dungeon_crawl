defmodule DungeonCrawl.DungeonInstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances

  describe "map_set_instances" do
    alias DungeonCrawl.DungeonInstances.MapSet

    test "get_map_set!/1 returns the map with given id" do
      msi = insert_stubbed_map_set_instance()
      assert %MapSet{} = DungeonInstances.get_map_set(msi.id)
      assert DungeonInstances.get_map_set(msi.id) == msi
      assert DungeonInstances.get_map_set!(msi.id) == msi
      refute DungeonInstances.get_map_set(msi.id + 1)
    end

    test "create_map_set/1" do
      map_set = insert_autogenerated_map_set(%{}, %{number: 2, number_north: 1, number_south: 4})
      dungeon = Repo.preload(map_set, :dungeons).dungeons |> Enum.at(0)

      assert {:ok, %{map_set: msi = %MapSet{}, maps: [instance]}} = DungeonInstances.create_map_set(map_set)
      assert Elixir.Map.take(map_set, [:name, :autogenerated, :state]) == Elixir.Map.take(msi, [:name, :autogenerated, :state])
      assert Elixir.Map.take(instance, [:name, :width, :height, :state, :number, :entrance,
                                        :number_north, :number_south, :number_east, :number_west,
                                        :animate_random, :animate_period, :animate_characters, :animate_colors, :animate_background_colors]) ==
             Elixir.Map.take(dungeon, [:name, :width, :height, :state, :number, :entrance,
                                       :number_north, :number_south, :number_east, :number_west,
                                       :animate_random, :animate_period, :animate_characters, :animate_colors, :animate_background_colors])
      assert _map_tile_details(dungeon) == _map_tile_details(instance)
      assert msi.passcode =~ ~r/^\w{8}$/
    end

    test "delete_map_set/1" do
      map_set = insert_stubbed_map_set_instance(%{active: true})
      map = Repo.preload(map_set, :maps).maps |> Enum.at(0)
      assert map_set = DungeonInstances.delete_map_set(map_set)
      assert %MapSet{} = map_set
      refute DungeonCrawl.Repo.get MapSet, map_set.id
      refute DungeonCrawl.Repo.get DungeonInstances.Map, map.id
    end
  end

  describe "map_instances" do
    alias DungeonCrawl.DungeonInstances.Map

    test "get_map!/1 returns the map with given id" do
      instance = insert_stubbed_dungeon_instance()
      assert DungeonInstances.get_map(instance.id) == instance
      assert DungeonInstances.get_map!(instance.id) == instance
    end

    test "get_map/2 returns the map in the map set instance for that number" do
      instance = insert_stubbed_dungeon_instance()
      assert DungeonInstances.get_map(instance.map_set_instance_id, instance.number) == instance
      refute DungeonInstances.get_map(instance.map_set_instance_id, 123)
    end

    test "get_adjacent_maps/1" do
      msi = insert_autogenerated_map_set_instance()
      instance = Repo.preload(msi, [:maps]).maps |> Enum.at(0)
      instance = Repo.update!(DungeonInstances.Map.changeset(instance, %{number_north: instance.number, number_south: instance.number}))

      assert %{"north" => instance, "south" => instance, "east" => %{id: nil}, "west" => %{id: nil}} ==
        DungeonInstances.get_adjacent_maps(instance.id)
    end

    test "create_map/1 copies a dungeon to a new instance" do
      msi = insert_autogenerated_map_set_instance()
      dungeon = Repo.preload(msi, [map_set: :dungeons]).map_set.dungeons |> Enum.at(0)

      assert {:ok, %{dungeon: instance = %Map{}}} = DungeonInstances.create_map(Elixir.Map.put(dungeon, :number, 2), msi.id)
      assert Elixir.Map.take(instance, [:name, :width, :height]) == Elixir.Map.take(dungeon, [:name, :width, :height])
      assert _map_tile_details(dungeon) == _map_tile_details(instance)
    end

    test "delete_map/1 deletes a dungeon instance" do
      msi = insert_autogenerated_map_set_instance()
      dungeon = Repo.preload(msi, [map_set: :dungeons]).map_set.dungeons |> Enum.at(0)
      {:ok, %{dungeon: instance = %Map{}}} = DungeonInstances.create_map(Elixir.Map.put(dungeon, :number, 2), msi.id)

      assert {:ok, %Map{}} = DungeonInstances.delete_map(instance)
      assert_raise Ecto.NoResultsError, fn -> DungeonInstances.get_map!(instance.id) end
    end

    test "delete_map!/1 deletes a dungeon instance" do
      msi = insert_autogenerated_map_set_instance()
      dungeon = Repo.preload(msi, [map_set: :dungeons]).map_set.dungeons |> Enum.at(0)
      {:ok, %{dungeon: instance = %Map{}}} = DungeonInstances.create_map(Elixir.Map.put(dungeon, :number, 2), msi.id)

      assert %Map{} = DungeonInstances.delete_map!(instance)
      assert_raise Ecto.NoResultsError, fn -> DungeonInstances.get_map!(instance.id) end
    end
  end

  describe "map_tile_instances" do
    alias DungeonCrawl.DungeonInstances.MapTile

    @valid_attrs %{row: 15, col: 42}
    @invalid_attrs %{row: nil}

    def map_tile_fixture(attrs \\ %{}, map_instance_id \\ nil) do
      instance = if map_instance_id do
                   Repo.get!(DungeonInstances.Map, map_instance_id)
                 else
                   insert_stubbed_dungeon_instance()
                 end

      tile_template = insert_tile_template()
      {:ok, map_tile} =
        Elixir.Map.merge(%MapTile{}, @valid_attrs)
        |> Elixir.Map.merge(%{map_instance_id: instance.id})
        |> Elixir.Map.merge(%{tile_template_id: tile_template.id})
        |> Elixir.Map.merge(attrs)
        |> Repo.insert()

      map_tile
    end

    test "get_map_tile/3 populated MapTile struct" do
      map_tile = Map.delete(map_tile_fixture(), :tile_template_id)
      assert ^map_tile = DungeonInstances.get_map_tile(map_tile.map_instance_id, map_tile.row, map_tile.col)
    end

    test "get_map_tile_by_id/1" do
      map_tile = Map.delete(map_tile_fixture(), :tile_template_id)
      assert ^map_tile = DungeonInstances.get_map_tile_by_id(map_tile.id)
    end

    test "new_map_tile/1 with valid data returns a populated MapTile struct" do
      other_map_tile = map_tile_fixture()
      assert {:ok, %MapTile{id: nil} = _map_tile} = DungeonInstances.new_map_tile(Map.merge @valid_attrs, Map.take(other_map_tile, [:map_instance_id, :tile_template_id]))
    end

    test "new_map_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DungeonInstances.new_map_tile(@invalid_attrs)
    end

    test "create_map_tile/1 with valid data creates a map_tile" do
      other_map_tile = map_tile_fixture()
      assert {:ok, %MapTile{} = _map_tile} = DungeonInstances.create_map_tile(Map.merge @valid_attrs, Map.take(other_map_tile, [:map_instance_id, :tile_template_id]))
    end

    test "create_map_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DungeonInstances.create_map_tile(@invalid_attrs)
    end

    test "update_map_tiles/1 updates valid changes" do
      map_tile_1 = map_tile_fixture(%{character: "0"})
      {:ok, map_tile_2} = DungeonInstances.create_map_tile(Map.merge @valid_attrs, Map.take(map_tile_1, [:character, :map_instance_id, :tile_template_id]))

      good_changeset = MapTile.changeset(map_tile_1, %{character: "Y"})
      bad_changeset = MapTile.changeset(map_tile_2, %{character: "XXX", color: "red"})

      assert {:ok, %{map_tile_updates: 2}} = DungeonInstances.update_map_tiles([good_changeset, bad_changeset])
      assert "Y" == Repo.get(MapTile, map_tile_1.id).character
      refute "XXX" == Repo.get(MapTile, map_tile_2.id).character
    end

    test "delete_map_tiles/1 deletes the map tiles with given ids" do
      map_tile_1 = map_tile_fixture(%{character: "0"})
      {:ok, map_tile_2} = DungeonInstances.create_map_tile(Map.merge @valid_attrs, Map.take(map_tile_1, [:character, :map_instance_id, :tile_template_id]))

      assert {1, nil} = DungeonInstances.delete_map_tiles([map_tile_1.id])
      refute Repo.get(MapTile, map_tile_1.id)
      assert Repo.get(MapTile, map_tile_2.id)
    end
  end

  # Utility methods
  defp _map_tile_details(dungeon) do
    Repo.preload(dungeon, :dungeon_map_tiles).dungeon_map_tiles
    |> Enum.map(fn(mt) -> Elixir.Map.take(mt, [:row, :col, :z_index, :character, :color, :background_color, :state, :script]) end)
    |> Enum.sort
  end
end

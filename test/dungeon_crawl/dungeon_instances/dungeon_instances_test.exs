defmodule DungeonCrawl.DungeonInstancesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonInstances

  describe "map_instances" do
    alias DungeonCrawl.DungeonInstances.Map

    test "get_map!/1 returns the map with given id" do
      dungeon = insert_stubbed_dungeon()
      instance = Repo.insert!(%Map{map_id: dungeon.id, name: dungeon.name, height: dungeon.height, width: dungeon.width})
      assert DungeonInstances.get_map!(instance.id) == instance
    end

    test "create_map/1 copies a dungeon to a new instance" do
      dungeon = insert_autogenerated_dungeon()

      assert {:ok, %{dungeon: instance = %Map{}}} = DungeonInstances.create_map(dungeon)
      assert Elixir.Map.take(instance, [:name, :width, :height]) == Elixir.Map.take(dungeon, [:name, :width, :height])
      assert _map_tile_details(dungeon) == _map_tile_details(instance)
    end

    defp _map_tile_details(dungeon) do
      Repo.preload(dungeon, :dungeon_map_tiles).dungeon_map_tiles
      |> Enum.map(fn(mt) -> Elixir.Map.take(mt, [:row, :col, :z_index, :tile_template_id, :character, :color, :background_color, :state, :script]) end)
      |> Enum.sort
    end

    test "delete_map/1 deletes a dungeon instance" do
      dungeon = insert_autogenerated_dungeon()
      {:ok, %{dungeon: instance = %Map{}}} = DungeonInstances.create_map(dungeon)

      assert {:ok, %Map{}} = DungeonInstances.delete_map(instance)
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
                          map = insert_stubbed_dungeon()
                          Repo.insert!(%DungeonInstances.Map{map_id: map.id, name: map.name, width: map.width, height: map.height})
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
end

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

    test "get_map_tile!/1 returns the map_tile with given id" do
      map_tile = map_tile_fixture()
      assert DungeonInstances.get_map_tile!(map_tile.id) == map_tile
    end

    test "create_map_tile/1 with valid data creates a map_tile" do
      other_map_tile = map_tile_fixture()
      assert {:ok, %MapTile{} = _map_tile} = DungeonInstances.create_map_tile(Map.merge @valid_attrs, Map.take(other_map_tile, [:map_instance_id, :tile_template_id]))
    end

    test "create_map_tile/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = DungeonInstances.create_map_tile(@invalid_attrs)
    end

    test "update_map_tile/2 with valid data updates the map_tile" do
      map_tile = map_tile_fixture()
      tile_template = insert_tile_template()
      old_tile_template = map_tile.tile_template_id
      assert {:ok, map_tile} = DungeonInstances.update_map_tile(map_tile, %{tile_template_id: tile_template.id})
      assert %MapTile{} = map_tile
      refute old_tile_template == map_tile.tile_template_id
    end

    test "update_map_tile/2 with invalid data returns error changeset" do
      map_tile = map_tile_fixture()
      assert {:error, %Ecto.Changeset{}} = DungeonInstances.update_map_tile(map_tile, @invalid_attrs)
      assert map_tile == DungeonInstances.get_map_tile!(map_tile.id)
    end

    test "get_map_tile/1 returns a map_tile from the top" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tile(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row, col: map_tile.col}) == map_tile
      refute DungeonInstances.get_map_tile(%{map_instance_id: map_tile.map_instance_id+1, row: map_tile.row, col: map_tile.col})
    end

    test "get_map_tile/2 returns a map_tile from the top in the given direction" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tile(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row+1, col: map_tile.col},   "up") == map_tile
      assert DungeonInstances.get_map_tile(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row-1, col: map_tile.col},   "down") == map_tile
      assert DungeonInstances.get_map_tile(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row,   col: map_tile.col+1}, "left") == map_tile
      assert DungeonInstances.get_map_tile(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row,   col: map_tile.col-1}, "right") == map_tile
    end

    test "get_map_tile/3 returns a map_tile" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tile(map_tile.map_instance_id, map_tile.row, map_tile.col) == map_tile
      refute DungeonInstances.get_map_tile(map_tile.map_instance_id + 1, map_tile.row, map_tile.col)
    end

    test "get_map_tile/4 returns a map tile in the given direction" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tile(map_tile.map_instance_id, map_tile.row+1, map_tile.col,   "up") == map_tile
      assert DungeonInstances.get_map_tile(map_tile.map_instance_id, map_tile.row-1, map_tile.col,   "down") == map_tile
      assert DungeonInstances.get_map_tile(map_tile.map_instance_id, map_tile.row,   map_tile.col+1, "left") == map_tile
      assert DungeonInstances.get_map_tile(map_tile.map_instance_id, map_tile.row,   map_tile.col-1, "right") == map_tile
    end

    test "get_map_tile!/2 returns a map tile in the given direction" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tile!(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row+1, col: map_tile.col},   "up") == map_tile
      assert DungeonInstances.get_map_tile!(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row-1, col: map_tile.col},   "down") == map_tile
      assert DungeonInstances.get_map_tile!(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row,   col: map_tile.col+1}, "left") == map_tile
      assert DungeonInstances.get_map_tile!(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row,   col: map_tile.col-1}, "right") == map_tile
    end

    test "get_map_tile!/4 returns a map tile in the given direction" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tile!(map_tile.map_instance_id, map_tile.row+1, map_tile.col,   "up") == map_tile
      assert DungeonInstances.get_map_tile!(map_tile.map_instance_id, map_tile.row-1, map_tile.col,   "down") == map_tile
      assert DungeonInstances.get_map_tile!(map_tile.map_instance_id, map_tile.row,   map_tile.col+1, "left") == map_tile
      assert DungeonInstances.get_map_tile!(map_tile.map_instance_id, map_tile.row,   map_tile.col-1, "right") == map_tile
    end

    test "get_map_tiles/1 returns a map_tile from the top" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tiles(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row, col: map_tile.col}) == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(%{map_instance_id: map_tile.map_instance_id+1, row: map_tile.row, col: map_tile.col}) == []
    end

    test "get_map_tiles/2 returns a map_tile from the top in the given direction" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tiles(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row+1, col: map_tile.col},   "up") == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row-1, col: map_tile.col},   "down") == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row,   col: map_tile.col+1}, "left") == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(%{map_instance_id: map_tile.map_instance_id, row: map_tile.row,   col: map_tile.col-1}, "right") == [map_tile, bottom_tile]
    end

    test "get_map_tiles/3 returns a map_tile" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tiles(map_tile.map_instance_id, map_tile.row, map_tile.col) == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(map_tile.map_instance_id + 1, map_tile.row, map_tile.col) == []
    end

    test "get_map_tiles/4 returns a map tile in the given direction" do
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.map_instance_id)
      assert DungeonInstances.get_map_tiles(map_tile.map_instance_id, map_tile.row+1, map_tile.col,   "up") == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(map_tile.map_instance_id, map_tile.row-1, map_tile.col,   "down") == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(map_tile.map_instance_id, map_tile.row,   map_tile.col+1, "left") == [map_tile, bottom_tile]
      assert DungeonInstances.get_map_tiles(map_tile.map_instance_id, map_tile.row,   map_tile.col-1, "right") == [map_tile, bottom_tile]
    end
  end
end

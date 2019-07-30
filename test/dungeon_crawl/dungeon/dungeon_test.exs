defmodule DungeonCrawl.DungeonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Dungeon

  describe "dungeons" do
    alias DungeonCrawl.Dungeon.Map

    @valid_attrs %{name: "some content"}
    @update_attrs %{name: "new name"}
    @invalid_attrs %{height: 1}

    def map_fixture(attrs \\ %{}) do
      {:ok, map} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Dungeon.create_map()

      map
    end

    test "list_dungeons/0 returns all dungeons" do
      map = map_fixture()
      assert Dungeon.list_dungeons() == [map]
    end

    test "list_dungeons/1 returns all dungeons owned by the user" do
      map_fixture()
      user = insert_user()
      map = map_fixture(%{user_id: user.id})
      assert Dungeon.list_dungeons(user) == [map]
    end

    test "list_dungeons_with_player_count/0 returns all dungeons preloaded with the players in the map instances" do
      map = insert_autogenerated_dungeon_instance()
      preloaded_dungeon = Repo.preload(Repo.preload(map, :dungeon).dungeon, [:user, :map_instances])
      preloaded_map_instances = Elixir.Map.put Enum.random(preloaded_dungeon.map_instances), :locations, []
      assert Dungeon.list_dungeons_with_player_count() ==
             [%{dungeon_id: map.map_id, dungeon: Elixir.Map.put(preloaded_dungeon, :map_instances, [preloaded_map_instances])}]
      p1 = insert_player_location(%{map_instance_id: map.id})
      p2 = insert_player_location(%{map_instance_id: map.id, user_id_hash: "different"})
      preloaded_map_instances = Elixir.Map.put Enum.random(preloaded_dungeon.map_instances), :locations, [p1,p2]
      assert Dungeon.list_dungeons_with_player_count() ==
             [%{dungeon_id: map.map_id, dungeon: Elixir.Map.put(preloaded_dungeon, :map_instances, [preloaded_map_instances])}]
    end

    test "list_active_dungeons_with_player_count/0 returns all dungeons preloaded with the players in the map instances that are active" do
      insert_autogenerated_dungeon_instance(%{active: false})
      insert_autogenerated_dungeon_instance(%{active: true, deleted_at: NaiveDateTime.utc_now})
      map = insert_stubbed_dungeon_instance(%{active: true})
      preloaded_dungeon = Repo.preload(Repo.preload(map, :dungeon).dungeon, [:user, :map_instances])
      p1 = insert_player_location(%{map_instance_id: map.id})
      preloaded_map_instances = Elixir.Map.put Enum.random(preloaded_dungeon.map_instances), :locations, [p1]
      assert Dungeon.list_active_dungeons_with_player_count() ==
             [%{dungeon_id: map.map_id, dungeon: Elixir.Map.put(preloaded_dungeon, :map_instances, [preloaded_map_instances])}]
    end

    test "get_map!/1 returns the map with given id" do
      map = map_fixture()
      assert Dungeon.get_map!(map.id) == map
    end

    test "next_version_exists?/1 is true if the map has a next version" do
      map = insert_stubbed_dungeon()
      _new_map = insert_stubbed_dungeon(%{previous_version_id: map.id})
      assert Dungeon.next_version_exists?(map)
    end

    test "next_version_exists?/1 is false if the map does not have a next version" do
      map = insert_stubbed_dungeon()
      refute Dungeon.next_version_exists?(map)
    end

    test "create_map/1 with valid data creates a map" do
      assert {:ok, %Map{} = _map} = Dungeon.create_map(@valid_attrs)
    end

    test "create_map/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Dungeon.create_map(@invalid_attrs)
    end

    test "create_new_map_version/1 does not create a new version of an inactive map" do
      map = insert_stubbed_dungeon(%{active: false})
      assert {:error, "Inactive map"} = Dungeon.create_new_map_version(map)
    end

    test "create_new_map_version/1 creates a new version" do
      map = insert_autogenerated_dungeon(%{active: true})
      assert {:ok, %{dungeon: new_map}} = Dungeon.create_new_map_version(map)
      assert new_map.version == map.version + 1

      assert %Map{} = new_map
      old_tiles = Repo.preload(map, :dungeon_map_tiles).dungeon_map_tiles |> Enum.map(fn(t) -> Elixir.Map.take(t, [:row, :col, :z_index, :tile_template_id]) end)
      new_tiles = Repo.preload(new_map, :dungeon_map_tiles).dungeon_map_tiles |> Enum.map(fn(t) -> Elixir.Map.take(t, [:row, :col, :z_index, :tile_template_id]) end)
      assert old_tiles == new_tiles
    end

    test "create_new_map_version/1 does not create a new version if the next one exists" do
      map = insert_stubbed_dungeon(%{active: true})
      _new_map = insert_stubbed_dungeon(%{previous_version_id: map.id})
      assert {:error, "New version already exists"} = Dungeon.create_new_map_version(map)
    end

    test "generate_map/2 returns an autogenerated map" do
      assert {:ok, %{dungeon: %Map{} = _map}} = Dungeon.generate_map(DungeonCrawl.DungeonGenerator.TestRooms, @valid_attrs)
    end

    test "generate_map/2 with invalid data returns error changeset" do
      assert {:error, :dungeon, %Ecto.Changeset{}, _others} = Dungeon.generate_map(DungeonCrawl.DungeonGenerator.TestRooms, @invalid_attrs)
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

    test "update_map/2 with invalid data returns error changeset" do
      map = map_fixture()
      assert {:error, %Ecto.Changeset{}} = Dungeon.update_map(map, @invalid_attrs)
      assert map == Dungeon.get_map!(map.id)
    end

    test "soft_delete_map/1 soft deletes the map" do
      map = map_fixture()
      assert {:ok, map} = Dungeon.delete_map(map)
      assert %Map{} = map
      assert map.deleted_at
    end

    test "activate_map/1 activates the map" do
      map = map_fixture()
      refute map.active
      assert {:ok, map} = Dungeon.activate_map(map)
      assert %Map{} = map
      assert map.active
    end

    test "tile_template_reference_count/1 returns a count of the template being used" do
      tile_a = insert_tile_template()
      tile_b = insert_tile_template()
      insert_stubbed_dungeon(%{}, [%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0},
                                   %{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0},
                                   %{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}])
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
      {:ok, map} = if dungeon_id, do: {:ok, Dungeon.get_map(dungeon_id)}, else: Dungeon.create_map(%{name: "test"})
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

    test "get_map_tile!/1 returns the map tile with given map values" do
      map_tile = map_tile_fixture()
      assert Dungeon.get_map_tile!(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col}) == map_tile
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
      bottom_tile = map_tile_fixture()
      map_tile = map_tile_fixture(%{z_index: 1}, bottom_tile.dungeon_id)
      assert Dungeon.get_map_tile(%{dungeon_id: map_tile.dungeon_id, row: map_tile.row, col: map_tile.col}) == map_tile
      refute Dungeon.get_map_tile(%{dungeon_id: map_tile.dungeon_id+1, row: map_tile.row, col: map_tile.col})
    end

    test "get_map_tile/3 returns a map_tile" do
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
  end
end

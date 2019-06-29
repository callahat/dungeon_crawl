defmodule DungeonCrawlWeb.TestHelpers do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.DungeonInstances

  def insert_user(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Some User",
      username: "user#{Base.encode16(:crypto.rand_bytes(8))}",
      password: "secretsauce",
    }, attrs)

    %DungeonCrawl.Account.User{}
    |> DungeonCrawl.Account.User.admin_changeset(changes)
    |> DungeonCrawl.Account.User.put_user_id_hash(:base64.encode(:crypto.strong_rand_bytes(24)))
    |> Repo.insert!()
  end

  def insert_tile_template(attrs \\ %{}) do
    changes= Map.merge(%{
      name: "Floor",
      description: "A dusty floor",
      character: ".",
      responders: "{move: {:ok}}"
    }, attrs)

    {:ok, tile_template} = TileTemplates.create_tile_template(changes)
    tile_template
  end

  def insert_openable_closable_tile_template_pair() do
    open_door = insert_tile_template(%{name: "open_door", character: "'"})
    closed_door = insert_tile_template(%{name: "open_door", character: "+"})

    {:ok, open_door}   = TileTemplates.update_tile_template(open_door, %{responders: "{move: {:ok}, close: {:ok, replace: [#{closed_door.id}]}}"})
    {:ok, closed_door} = TileTemplates.update_tile_template(closed_door, %{responders: "{open: {:ok, replace: [#{open_door.id}]}}"})
    {open_door, closed_door}
  end

  def insert_autogenerated_dungeon_instance(attrs \\ %{}) do
    dungeon = insert_autogenerated_dungeon(attrs)
    {:ok, %{dungeon: instance}} = DungeonInstances.create_map(dungeon)
    instance
  end

  def insert_autogenerated_dungeon(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Autogenerated",
      height: 20,
      width: 20
    }, attrs)

    {:ok, %{dungeon: dungeon}} = DungeonCrawl.Dungeon.generate_map(DungeonCrawl.DungeonGenerator.TestRooms, changes)
    dungeon
  end

  def insert_stubbed_dungeon_instance(attrs \\ %{}, tiles \\ []) do
    dungeon = insert_stubbed_dungeon(attrs, tiles)
    {:ok, %{dungeon: instance}} = DungeonInstances.create_map(dungeon)
    instance
  end

  def insert_stubbed_dungeon(attrs \\ %{}, tiles \\ []) do
    changes = Map.merge(%DungeonCrawl.Dungeon.Map{
      name: "Stubbed",
      height: 20,
      width: 20
    }, attrs)

    dungeon = DungeonCrawl.Dungeon.change_map(changes) |> Repo.insert!
    Repo.insert_all(DungeonCrawl.Dungeon.MapTile, _tile_hydrator(dungeon.id, tiles))
    dungeon
  end

  defp _tile_hydrator(dungeon_id, tiles) do
    tiles
    |> Enum.map(fn(t) -> %{dungeon_id: dungeon_id, row: t.row, col: t.col, tile_template_id: t.tile_template_id, z_index: t.z_index} end)
  end

  def insert_player_map_tile(attrs \\ %{}) do
    changes = Map.merge(%{
      row: 3,
      col: 1,
    }, attrs)

    player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()

    Map.take(changes, [:map_instance_id, :row, :col])
    |> Map.merge(%{tile_template_id: player_tile_template.id, z_index: 1})
    |> DungeonCrawl.DungeonInstances.create_map_tile!()
  end

  def insert_player_location(attrs \\ %{}) do
    changes = Map.merge(%{
      user_id_hash: "good_hash",
    }, attrs)

    map_tile_id = if changes[:map_tile_instance_id], do: changes[:map_tile_instance_id], else: insert_player_map_tile(changes).id

    DungeonCrawl.Player.create_location!(%{user_id_hash: changes.user_id_hash, map_tile_instance_id: map_tile_id})
  end
end

defmodule DungeonCrawlWeb.TestHelpers do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.MapGenerators.TestRooms
  alias DungeonCrawl.Scores

  def insert_user(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Some User",
      username: "user#{Base.encode16(:crypto.strong_rand_bytes(8))}",
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
      state: "blocking: false",
      script: ""
    }, attrs)

    {:ok, tile_template} = TileTemplates.create_tile_template(changes)
    tile_template
  end

  def insert_autogenerated_dungeon_instance(attrs \\ %{}) do
    dungeon = insert_autogenerated_dungeon(attrs)

    {:ok, %{map_set: _, maps: [instance | _]}} = DungeonInstances.create_map_set(Repo.preload(dungeon, :map_set).map_set)
    instance
  end

  def insert_autogenerated_dungeon(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Autogenerated",
      height: 21,
      width: 21,
      active: true,
      map_set_id: attrs[:map_set_id] || insert_map_set(Map.put(attrs, :autogenerated, true)).id
    }, attrs)

    {:ok, %{dungeon: dungeon}} = Dungeons.generate_map(TestRooms, changes)
    dungeon
  end

  def insert_map_set(attrs \\ %{}) do
    attrs = Map.merge(%{
      name: "Autogenerated",
      active: true
    }, attrs)

    {:ok, map_set} = Dungeons.create_map_set(attrs)
    map_set
  end

  def insert_autogenerated_map_set(attrs \\ %{}, map_attrs \\ %{}) do
    map_set = insert_map_set(Map.put(attrs, :autogenerated, true))
    insert_autogenerated_dungeon(Map.put(map_attrs, :map_set_id, map_set.id))
    map_set
  end

  def insert_autogenerated_map_set_instance(attrs \\ %{}, map_attrs \\ %{}) do
    map_set = insert_map_set(Map.put(attrs, :autogenerated, true))
    insert_autogenerated_dungeon(Map.put(map_attrs, :map_set_id, map_set.id))
    {:ok, %{map_set: map_set_instance, maps: _}} = DungeonInstances.create_map_set(map_set, attrs[:is_private])
    map_set_instance
  end

  def insert_stubbed_map_set_instance(attrs \\ %{}, map_attrs \\ %{}, maps \\ [[]]) do
    map_set = insert_stubbed_map_set(attrs, map_attrs, maps)
    {:ok, %{map_set: map_set_instance, maps: _}} = DungeonInstances.create_map_set(map_set)
    map_set_instance
  end

  def insert_stubbed_map_set(attrs \\ %{}, map_attrs \\ %{}, maps \\ [[]]) do
    map_set = insert_map_set(attrs)
    Enum.reduce(maps, 1, fn(tiles, num) ->
      insert_stubbed_dungeon(Map.merge(map_attrs, %{map_set_id: map_set.id, number: num}), tiles)
      num + 1
    end)
    map_set
  end

  def insert_stubbed_dungeon_instance(attrs \\ %{}, tiles \\ []) do
    dungeon = insert_stubbed_dungeon(attrs, tiles)
    {:ok, %{map_set: msi}} = DungeonInstances.create_map_set(Repo.preload(dungeon,:map_set).map_set)
    Enum.at(Repo.preload(msi, :maps).maps, 0)
  end

  def insert_stubbed_dungeon(attrs \\ %{}, tiles \\ []) do
    changes = Map.merge(%Dungeons.Map{
      name: "Stubbed",
      height: 20,
      width: 20,
      map_set_id: attrs[:map_set_id] || insert_map_set(attrs).id
    }, attrs)

    dungeon = Dungeons.change_map(changes) |> Repo.insert!
    Repo.insert_all(Dungeons.MapTile, _tile_hydrator(dungeon.id, tiles))
    dungeon
  end

  defp _tile_hydrator(dungeon_id, tiles) do
    tiles
    |> Enum.map(fn(t) -> %{dungeon_id: dungeon_id,
                           row: t.row,
                           col: t.col,
                           tile_template_id: Map.get(t, :tile_template_id),
                           z_index: t.z_index,
                           character: t.character,
                           color: Map.get(t, :color),
                           background_color: Map.get(t, :background_color),
                           state: Map.get(t, :state),
                           script: Map.get(t, :script),
                           name: Map.get(t, :name),
                           animate_random: Map.get(t, :animate_random),
                           animate_period: Map.get(t, :animate_period),
                           animate_characters: Map.get(t, :animate_characters),
                           animate_colors: Map.get(t, :animate_colors),
                           animate_background_colors: Map.get(t, :animate_background_colors)
                          } end)
  end

  def insert_player_map_tile(attrs \\ %{}) do
    changes = Map.merge(%{
      row: 3,
      col: 1,
      character: "@",
      script: ""
    }, attrs)

    player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()

    %{state: player_tile_template.state}
    |> Map.merge(Map.take(changes, [:map_instance_id, :row, :col, :character, :state, :script]))
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

  def insert_score(map_set_id, attrs \\ %{}) do
    changes = Map.merge(%{
      victory: true,
      result: "Win",
      score: 10,
      steps: 300,
      user_id_hash: "insert_score",
      map_set_id: map_set_id,
      duration: 1000
    }, attrs)

    {:ok, score} = Scores.create_score(changes)
    score
  end
end

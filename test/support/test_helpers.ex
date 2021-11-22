defmodule DungeonCrawlWeb.TestHelpers do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonGeneration.MapGenerators.TestRooms
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

  def insert_item(attrs \\ %{}) do
    changes= Map.merge(%{
      name: "Whip",
      description: "crack that whip",
      script: "#end"
    }, attrs)

    {:ok, item} = Equipment.create_item(changes)
    item
  end

  def insert_autogenerated_level_instance(attrs \\ %{}) do
    level = insert_autogenerated_level(attrs)

    {:ok, %{dungeon: _, levels: [instance | _]}} = DungeonInstances.create_dungeon(Repo.preload(level, :dungeon).dungeon)
    instance
  end

  def insert_autogenerated_level(attrs \\ %{}) do
    changes = Map.merge(%{
      name: "Autogenerated",
      height: 21,
      width: 21,
      active: true,
      dungeon_id: attrs[:dungeon_id] || insert_dungeon(Map.put(attrs, :autogenerated, true)).id
    }, attrs)

    {:ok, %{level: level}} = Dungeons.generate_level(TestRooms, changes)
    level
  end

  def insert_dungeon(attrs \\ %{}) do
    attrs = Map.merge(%{
      name: "Autogenerated",
      active: true
    }, attrs)

    {:ok, dungeon} = Dungeons.create_dungeon(attrs)
    dungeon
  end

  def insert_autogenerated_dungeon(attrs \\ %{}, level_attrs \\ %{}) do
    dungeon = insert_dungeon(Map.put(attrs, :autogenerated, true))
    insert_autogenerated_level(Map.put(level_attrs, :dungeon_id, dungeon.id))
    dungeon
  end

  def insert_autogenerated_dungeon_instance(attrs \\ %{}, level_attrs \\ %{}) do
    dungeon = insert_dungeon(Map.put(attrs, :autogenerated, true))
    insert_autogenerated_level(Map.put(level_attrs, :dungeon_id, dungeon.id))
    {:ok, %{dungeon: dungeon_instance, levels: _}} = DungeonInstances.create_dungeon(dungeon, attrs[:is_private])
    dungeon_instance
  end

  def insert_stubbed_dungeon_instance(attrs \\ %{}, level_attrs \\ %{}, levels \\ [[]]) do
    dungeon = insert_stubbed_dungeon(attrs, level_attrs, levels)
    {:ok, %{dungeon: dungeon_instance, levels: _}} = DungeonInstances.create_dungeon(dungeon)
    dungeon_instance
  end

  def insert_stubbed_dungeon(attrs \\ %{}, level_attrs \\ %{}, levels \\ [[]]) do
    dungeon = insert_dungeon(attrs)
    Enum.reduce(levels, 1, fn(tiles, num) ->
      insert_stubbed_level(Map.merge(level_attrs, %{dungeon_id: dungeon.id, number: num}), tiles)
      num + 1
    end)
    dungeon
  end

  def insert_stubbed_level_instance(attrs \\ %{}, tiles \\ []) do
    level = insert_stubbed_level(attrs, tiles)
    {:ok, %{dungeon: di}} = DungeonInstances.create_dungeon(Repo.preload(level,:dungeon).dungeon)
    Enum.at(Repo.preload(di, :levels).levels, 0)
  end

  def insert_stubbed_level(attrs \\ %{}, tiles \\ []) do
    changes = Map.merge(%Dungeons.Level{
      name: "Stubbed",
      height: 20,
      width: 20,
      dungeon_id: attrs[:dungeon_id] || insert_dungeon(attrs).id
    }, attrs)

    level = Dungeons.change_level(changes) |> Repo.insert!
    Repo.insert_all(Dungeons.Tile, _tile_hydrator(level.id, tiles))
    level
  end

  defp _tile_hydrator(level_id, tiles) do
    tiles
    |> Enum.map(fn(t) -> %{level_id: level_id,
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

  def insert_player_tile(attrs \\ %{}) do
    changes = Map.merge(%{
      row: 3,
      col: 1,
      character: "@",
      script: ""
    }, attrs)

    player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()

    %{state: player_tile_template.state}
    |> Map.merge(Map.take(changes, [:level_instance_id, :row, :col, :character, :state, :script]))
    |> Map.merge(%{tile_template_id: player_tile_template.id, z_index: 1})
    |> DungeonCrawl.DungeonInstances.create_tile!()
  end

  def insert_player_location(attrs \\ %{}) do
    changes = Map.merge(%{
      user_id_hash: "good_hash",
    }, attrs)

    tile_id = if changes[:tile_instance_id], do: changes[:tile_instance_id], else: insert_player_tile(changes).id

    DungeonCrawl.Player.create_location!(%{user_id_hash: changes.user_id_hash, tile_instance_id: tile_id})
  end

  def insert_score(dungeon_id, attrs \\ %{}) do
    changes = Map.merge(%{
      victory: true,
      result: "Win",
      score: 10,
      steps: 300,
      user_id_hash: "insert_score",
      dungeon_id: dungeon_id,
      duration: 1000
    }, attrs)

    {:ok, score} = Scores.create_score(changes)
    score
  end
end

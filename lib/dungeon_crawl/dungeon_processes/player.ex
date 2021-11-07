defmodule DungeonCrawl.DungeonProcesses.Player do
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Player
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.DungeonProcesses.{Levels, LevelProcess, Registrar}
  alias DungeonCrawl.TileTemplates

  @stats [:health, :gems, :cash, :ammo, :score, :lives, :torches]

  @doc """
  Returns the current stats (health, gems, cash, ammo, torches, torch_light, etc) for the player.
  When the instance state object is already available, that along with the player
  tile should be used to get the player stats.
  When only the player location is available, or an instance state is not already available
  (ie, stats are needed outside of `LevelProcess.run_with` or outside of a `Command` method)
  a `user_id_hash` should be used along to get the stats for that player's current location.
  `equipped` will be populated with a list of [<slug>, <name>] from the item, and is returned
  for both forms of `current_stats`. `equipment` is included when an instance state and player_tile
  are given, and will be a list of [<slug>, <name>] tuples for the player tile's current equipment.

  ## Examples

      iex> current_stats(%Levels{}, player_tile)
      %{health: 100, gems: 0, ... , equipped: {"gun", "Gun"}, equipment: [{"gun", "Gun"}, {"hands", "Fisticuffs"}]}

      iex> current_stats("useridhash123")
      %{health: 100, gems: 0, ... , equipped: {"gun", "Gun"}}
  """
  def current_stats(%Levels{} = state, %{id: tile_id} = _player_tile) do
    case Levels.get_tile_by_id(state, %{id: tile_id}) do
      nil ->
        %{}
      player_tile ->
        _current_stats(player_tile)
        |> _with_equipped_and_equipment(player_tile, state)
    end
  end

  def current_stats(user_id_hash) do
    with player_location when not is_nil(player_location) <- Player.get_location(user_id_hash),
         player_location <- DungeonCrawl.Repo.preload(player_location, [tile: :level]),
         player_level_instance <- player_location.tile.level,
         {:ok, instance_process} <- Registrar.instance_process(player_level_instance.dungeon_instance_id, player_level_instance.id),
         player_tile when not is_nil(player_tile) <- LevelProcess.get_tile(instance_process, player_location.tile_instance_id) do
      _current_stats(player_tile)
      |> _with_equipped(player_tile)
    else
      _ ->
        %{}
    end
  end

  defp _current_stats(tile) do
    keys = _door_keys(tile)
           |> Enum.map(fn {k,v} -> {String.replace_suffix(to_string(k), "_key",""), v} end)
           |> Enum.map(fn {color, count} ->
                num = if count > 1, do: "<span class='smaller'>x#{count}</span>", else: ""
                "<pre class='tile_template_preview'><span style='color: #{color};'>♀</span>#{num}</pre>"
              end)
           |> Enum.join("")
    torch_light = _torch_light(tile)

    %{health: 0, gems: 0, cash: 0, ammo: 0, score: 0, lives: -1, torches: 0}
    |> Map.merge(Map.take(tile.parsed_state, @stats))
    |> Map.put(:keys, keys)
    |> Map.put(:torch_light, torch_light)
  end

  defp _door_keys(%{parsed_state: parsed_state} = _tile), do: _door_keys(parsed_state)
  defp _door_keys(parsed_state) do
    parsed_state
    |> Map.to_list
    |> Enum.filter(fn {k,v} -> Regex.match?(~r/_key$/, to_string(k)) && v && v > 0 end)
  end

  defp _torch_light(%{parsed_state: parsed_state} = _tile), do: _torch_light(parsed_state)
  defp _torch_light(parsed_state) do
    if is_nil(parsed_state[:torch_light]) || parsed_state[:torch_light] == 0 do
      ""
    else
      meter_length = min(parsed_state[:torch_light], 6)
      chars = String.duplicate("█", meter_length) <> String.duplicate("░", 6 - meter_length)
      "<pre class='tile_template_preview'><span class='torch-bar'>#{chars}</span></pre>"
    end
  end

  def _with_equipped_and_equipment(stats, player_tile, state) do
    {equipped, _, _} = Levels.get_item(player_tile.parsed_state[:equipped], state)
    equipped_slug = equipped && equipped.slug
    equipped_name = equipped && equipped.name
    equipment = ((player_tile.parsed_state[:equipment] || []) -- [equipped_slug])
                |> Enum.map(fn item_slug ->
                     {item, _, _} = Levels.get_item(item_slug, state)
                     item
                   end)
                |> Enum.reject(&(is_nil(&1)))
                |> Enum.map(fn item -> _item_span_decorator(item) end)
    equipment = if is_nil(equipped),
                   do: equipment,
                   else: ["<span>-#{ equipped_name } (Equipped)</span>" | equipment]

    Map.merge(stats, %{equipped: equipped_name,
                       equipment: equipment })
  end

  def _with_equipped(stats, player_tile) do
    equipped = Equipment.get_item(player_tile.parsed_state[:equipped])
    Map.put(stats, :equipped, equipped && equipped.name)
  end

  def _item_span_decorator(item) do
    "<span class='btn-link messageLink' data-item-slug='#{ item.slug }'>▶#{ item.name }</span>"
  end

  @doc """
  Buries the [dead] player. This places a grave tile above the players current location,
  taking all the players items (ammo, cash, keys, etc), making them available to be picked up.
  The grave robber will be pick up everything (even if it might be above a certain limit,
  such as only letting a player carry one of a type of key).
  """
  def bury(%Levels{} = state, %{id: tile_id} = _player_tile) do
    player_tile = Levels.get_tile_by_id(state, %{id: tile_id})
    original_player_tile_state = player_tile.parsed_state

    bottom_z_index = Enum.at(Levels.get_tiles(state, player_tile), -1).z_index
    last_player_z_index = player_tile.z_index

    {player_tile, state} = Levels.update_tile(state, player_tile, %{z_index: bottom_z_index - 1})
    deaths = case player_tile.parsed_state[:deaths] do
               nil    -> 1
               deaths -> deaths + 1
             end

    starting_equipment = String.split(player_tile.parsed_state[:starting_equipment] || "")

    new_state = _door_keys(player_tile)
                |> Enum.into(%{}, fn {k,_v} -> {k, 0} end)
                |> Map.merge(%{pushable: false,
                               health: 0,
                               gems: 0,
                               cash: 0,
                               ammo: 0,
                               torches: 0,
                               torch_light: 0,
                               buried: true,
                               deaths: deaths,
                               equipment: starting_equipment,
                               equipped: Enum.at(starting_equipment || [], 0)})
    {player_tile, state} = Levels.update_tile_state(state, player_tile, new_state)

    script_fn = fn items -> """
                            :TOP
                            #END
                            :TOUCH
                            #IF not ?sender@player, TOP
                            Here lies #{player_tile.name || "Unknown"}
                            !DEFILE;Dig up the grave?
                            !TOP;Do nothing
                            #END
                            :DEFILE
                            You defile the grave
                            #{items}
                            #IF ?random@4 == 1
                            #BECOME slug: zombie
                            #DIE
                            """
                end

    _spawn_loot_tile(state, :grave, script_fn, original_player_tile_state, player_tile, last_player_z_index)
  end

  @doc """
  Takes all the players items and drops them in a pile. This places a junk pile tile above the player's current location.
  Mean to be used when a player leaves, as this will not update the player tile since it should be deleted upon
  the player leaving.
  """
  def drop_all_items(%Levels{} = state, %{id: tile_id} = _player_tile) do
    player_tile = Levels.get_tile_by_id(state, %{id: tile_id})

    z_index_plus_one = Enum.at(Levels.get_tiles(state, player_tile), 0).z_index + 1

    # maybe have a rat pop out sometimes?
    script_fn = fn items -> """
                            :TOP
                            #END
                            :TOUCH
                            #IF not ?sender@player, TOP
                            Someone left behind a pile of trash, maybe there
                            is something other than typhus among the debris.
                            !GRAB;Dig through it?
                            !TOP;Don't touch it
                            #END
                            :GRAB
                            You rummage through the refuse...
                            #{items}
                            #DIE
                            """
                end

    _spawn_loot_tile(state, :junk_pile, script_fn, player_tile.parsed_state, player_tile, z_index_plus_one)
  end

  defp _spawn_loot_tile(%Levels{} = state, tile_template, script_fn, original_state, player_tile, z_index) do
    # items that really are stored as state variables
    items_stolen = Map.take(original_state, [:gems, :cash, :ammo, :torches])
                   |> Map.to_list
                   |> Enum.concat(_door_keys(original_state))
                   |> Enum.reject(fn {_, count} -> count <= 0 end)
                   |> Enum.reduce([[], []], fn {item, count}, [words, gives] ->
                        [ ["Found #{count} #{item}" | words],
                          ["#GIVE #{item}, #{count}, ?sender" | gives] ]
                      end)

    # add the equippable items
    items_stolen = ((original_state[:equipment] || []) -- (player_tile.parsed_state[:equipment] || []))
                   |> Enum.reduce(items_stolen, fn item_slug, [words, equips] ->
                           {item, _, _} = Levels.get_item(item_slug, state)
                           [ [ "Found a #{item.name}" | words],
                             [ "#EQUIP #{item_slug}, ?sender" | equips]]
                         end)
                      |> Enum.flat_map(&(&1))
                      |> Enum.join("\n")

    # TODO: tile spawning (including player character tile) should probably live somewhere else once a pattern emerges
    tile_template = apply(DungeonCrawl.TileTemplates.TileSeeder, tile_template, [])
    tile = Map.take(player_tile, [:level_instance_id, :row, :col])
           |> Map.merge(%{z_index: z_index})
           |> Map.merge(TileTemplates.copy_fields(tile_template))
           |> Map.put(:script, script_fn.(items_stolen))
           |> DungeonCrawl.DungeonInstances.create_tile!()
    Levels.create_tile(state, tile)
  end

  @doc """
  Turns a player tile into a statue. This also removes the player location effectively kicking them from
  the dungeon. It can be used when a player has "idled out" meaning they closed the window or just stopped
  playing without actually leaving the dungeon.
  """
  def petrify(%Levels{} = state, player_tile) do
    location = Levels.get_player_location(state, %{id: player_tile.id})

    {junk_pile, state} = drop_all_items(state, player_tile)
    {_, state} = Levels.delete_tile(state, player_tile)
    Player.delete_location!(location)

    # spawn statue
    z_index_plus_one = Enum.at(Levels.get_tiles(state, junk_pile), 0).z_index + 1
    tile_template = DungeonCrawl.TileTemplates.TileSeeder.statue_tile()
    tile = Map.take(junk_pile, [:level_instance_id, :row, :col])
           |> Map.merge(%{z_index: z_index_plus_one})
           |> Map.merge(TileTemplates.copy_fields(tile_template))
           |> DungeonCrawl.DungeonInstances.create_tile!()
    Levels.create_tile(state, tile)
  end

  @doc """
  Respawns a player. This will move their associated tile to a spawn coordinate in the instance,
  and restore health to 100.
  """
  def respawn(%Levels{} = state, player_tile) do
    new_coords = _respawn_coordinates(state, player_tile)
    {player_tile, state} = Levels.update_tile(state, player_tile, new_coords)
    Levels.update_tile_state(state, player_tile, %{health: 100, buried: false, pushable: true })
  end

  defp _respawn_coordinates(state, %{parsed_state: player_state} = player_tile) do
    if state.state_values[:respawn_at_entry] != false && player_state[:entry_row] && player_state[:entry_col] do
      _relocated_coordinates_with_z(state, %{row: player_state.entry_row, col: player_state.entry_col})
    else
      _relocated_coordinates(state, player_tile)
    end
  end

  defp _respawn_coordinates(state, player_tile) do
    _relocated_coordinates(state, player_tile)
  end

  @doc """
  Resets a player to their entry coordinates, or a spawn location if `respawn_at_entry` false.
  """
  def reset(%Levels{} = state, player_tile) do
    new_coords = _respawn_coordinates(state, player_tile)
    Levels.update_tile(state, player_tile, new_coords)
  end

  @doc """
  Places a player tile in the given instance. By default, it will place the player on
  a spawn location.
  """
  def place(%Levels{} = state, %Tile{} = player_tile, %Location{} = location) do
    new_coords = _relocated_coordinates(state, player_tile)
    _place(state, player_tile, location, new_coords)
  end

  def place(%Levels{} = state, %Tile{} = player_tile, %Location{} = location, %{edge: _} = passage) do
    new_coords = _relocated_coordinates(state, player_tile, passage)
    _place(state, player_tile, location, new_coords)
  end

  def place(%Levels{} = state, %Tile{} = player_tile, %Location{} = location, %{match_key: _} = passage) do
    new_coords = _relocated_coordinates(state, player_tile, passage)
    _place(state, player_tile, location, new_coords)
  end

  defp _place(%Levels{instance_id: instance_id} = state, %Tile{} = player_tile, %Location{} = location, new_coords) do
    if player_tile.level_instance_id == instance_id do
      Levels.update_tile(state, player_tile, new_coords)
    else
      new_coords =  Map.put(new_coords, :level_instance_id, instance_id)
      player_tile = Map.merge(player_tile, new_coords)
      Levels.create_player_tile(state, player_tile, location)
    end
  end

  defp _relocated_coordinates(%Levels{spawn_coordinates: spawn_coordinates} = state, player_tile) do
    {row, col} = case spawn_coordinates do
                    []     -> {round(:math.fmod(player_tile.row, state.state_values.height)),
                               round(:math.fmod(player_tile.col, state.state_values.width))}
                    coords -> Enum.random(coords)
                 end

    _relocated_coordinates_with_z(state, %{row: row, col: col})
  end

  defp _relocated_coordinates(%Levels{state_values: %{rows: rows, cols: cols}} = state, player_tile, %{edge: edge}) do
    {row, col} = case edge do
                   "north" -> {0, player_tile.col}
                   "south" -> {rows - 1, player_tile.col}
                   "east" -> {player_tile.row, cols - 1}
                   _west  -> {player_tile.row, 0}
                 end

    _relocated_coordinates_with_z(state, %{row: floor(:math.fmod(row, rows)), col: floor(:math.fmod(col, cols))})
  end

  defp _relocated_coordinates(%Levels{passage_exits: passage_exits} = state, player_tile, %{match_key: match_key} = passage) do
    matched_exits = if is_nil(match_key),
                         do:   passage_exits,
                         else: Enum.filter(passage_exits, fn {_id, mk} -> mk == match_key end)

    case Enum.map(matched_exits, fn {id, _} -> id end) do
      [] ->
        _relocated_coordinates(state, player_tile)

      exit_ids ->
        passage_exit_id =\
        if length(exit_ids) > 1 do
          Enum.reject(exit_ids, fn id ->
            Map.take(Levels.get_tile_by_id(state, %{id: id}) || %{}, [:row, :col]) == Map.take(passage, [:row, :col])
          end)
          |> Enum.random()
        else
          Enum.random(exit_ids)
        end

        spawn_location = Levels.get_tile_by_id(state, %{id: passage_exit_id})
        _relocated_coordinates_with_z(state, spawn_location)
    end
  end

  defp _relocated_coordinates_with_z(state, spawn_location) do
    top_tile = Levels.get_tile(state, spawn_location)
    z_index = if top_tile, do: top_tile.z_index + 1, else: 0
    %{row: spawn_location.row, col: spawn_location.col, z_index: z_index}
  end

  @doc """
  Returns a list of the stats that the sidebar stat panel tracks.
  """
  def stats(), do: @stats
end

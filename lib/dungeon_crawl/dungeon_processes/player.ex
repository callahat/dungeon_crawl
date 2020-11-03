defmodule DungeonCrawl.DungeonProcesses.Player do
  alias DungeonCrawl.Player
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.DungeonProcesses.{Instances, InstanceRegistry, InstanceProcess}

  @doc """
  Returns the current stats (health, gems, cash, and ammo) for the player.
  When the instance state object is already available, that along with the player
  map tile should be used to get the player stats.
  When only the player location is available, or an instance state is not already available
  (ie, stats are needed outside of `InstanceProcess.run_with` or outside of a `Command` method)
  a `user_id_hash` should be used along to get the stats for that player's current location.
  """
  def current_stats(%Instances{} = state, %{id: map_tile_id} = _player_tile) do
    case Instances.get_map_tile_by_id(state, %{id: map_tile_id}) do
      nil ->
        %{}
      player_tile ->
        _current_stats(player_tile)
    end
  end

  def current_stats(user_id_hash) do
    with player_location when not is_nil(player_location) <- Player.get_location(user_id_hash),
         player_location <- DungeonCrawl.Repo.preload(player_location, :map_tile),
         {:ok, instance_state} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, player_location.map_tile.map_instance_id),
         player_tile when not is_nil(player_tile) <- InstanceProcess.get_tile(instance_state, player_location.map_tile_instance_id) do
      _current_stats(player_tile)
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

    %{health: 0, gems: 0, cash: 0, ammo: 0}
    |> Map.merge(Map.take(tile.parsed_state, [:health, :gems, :cash, :ammo]))
    |> Map.put(:keys, keys)
  end

  defp _door_keys(tile) do
    tile.parsed_state
    |> Map.to_list
    |> Enum.filter(fn {k,v} -> Regex.match?(~r/_key$/, to_string(k)) && v && v > 0 end)
  end

  @doc """
  Buries the [dead] player. This places a grave map tile above the players current location,
  taking all the players items (ammo, cash, keys, etc), making them available to be picked up.
  The grave robber will be pick up everything (even if it might be above a certain limit,
  such as only letting a player carry one of a type of key).
  """
  def bury(%Instances{} = state, %{id: map_tile_id} = _player_tile) do
    player_tile = Instances.get_map_tile_by_id(state, %{id: map_tile_id})
    grave_tile_template = DungeonCrawl.TileTemplates.TileSeeder.grave()

    items_stolen = Map.take(player_tile.parsed_state, [:gems, :cash, :ammo])
                   |> Map.to_list
                   |> Enum.concat(_door_keys(player_tile))
                   |> Enum.reject(fn {_, count} -> count <= 0 end)
                   |> Enum.map(fn {item, count} ->
                        """
                        Found #{count} #{item}
                        #GIVE #{item}, #{count}, ?sender
                        """
                      end)
                   |> Enum.join("\n")

    bottom_z_index = Enum.at(Instances.get_map_tiles(state, player_tile), -1).z_index
    last_player_z_index = player_tile.z_index

    {player_tile, state} = Instances.update_map_tile(state, player_tile, %{z_index: bottom_z_index - 1})
    deaths = case player_tile.parsed_state[:deaths] do
               nil    -> 1
               deaths -> deaths + 1
             end
    new_state = _door_keys(player_tile)
                |> Enum.into(%{}, fn {k,_v} -> {k, 0} end)
                |> Map.merge(%{pushable: false, health: 0, gems: 0, cash: 0, ammo: 0, buried: true, deaths: deaths})
    {player_tile, state} = Instances.update_map_tile_state(state, player_tile, new_state)

    script = """
             :TOP
             #END
             :TOUCH
             #IF not ?sender@player, TOP
             Here lies #{player_tile.name || "Unknown"}
             !DEFILE;Dig up the grave?
             #END
             :DEFILE
             You defile the grave
             #{items_stolen}
             #IF ?random@4 == 1
             #BECOME slug: zombie
             #DIE
             """

    # TODO: tile spawning (including player character tile) should probably live somewhere else once a pattern emerges
    grave = Map.take(player_tile, [:map_instance_id, :row, :col])
             |> Map.merge(%{tile_template_id: grave_tile_template.id, z_index: last_player_z_index})
             |> Map.merge(Map.take(grave_tile_template, [:character, :color, :background_color, :state, :script]))
             |> Map.put(:script, script)
             |> DungeonCrawl.DungeonInstances.create_map_tile!()
    Instances.create_map_tile(state, grave)
  end

  @doc """
  Respawns a player. This will move their associated map tile to a spawn coordinate in the instance,
  and restore health to 100.
  """
  def respawn(%Instances{} = state, player_tile) do
    new_coords = _relocated_coordinates(state, player_tile)
    {player_tile, state} = Instances.update_map_tile(state, player_tile, new_coords)
    Instances.update_map_tile_state(state, player_tile, %{health: 100, buried: false, pushable: true })
  end

  @doc """
  Places a player tile in the given instance. By default, it will place the player on
  a spawn location.
  """
  def place(%Instances{} = state, %MapTile{} = player_tile, %Location{} = location) do
    new_coords = _relocated_coordinates(state, player_tile)
    _place(state, player_tile, location, new_coords)
  end

  def place(%Instances{} = state, %MapTile{} = player_tile, %Location{} = location, %{} = passage, passage_match_key) do
    new_coords = _relocated_coordinates(state, player_tile, passage, passage_match_key)
    _place(state, player_tile, location, new_coords)
  end

  defp _place(%Instances{instance_id: instance_id} = state, %MapTile{} = player_tile, %Location{} = location, new_coords) do
    if player_tile.map_instance_id == instance_id do
      Instances.update_map_tile(state, player_tile, new_coords)
    else
      new_coords =  Map.put(new_coords, :map_instance_id, instance_id)
      player_tile = Map.merge(player_tile, new_coords)
      Instances.create_player_map_tile(state, player_tile, location)
    end
  end

  defp _relocated_coordinates(%Instances{spawn_coordinates: spawn_coordinates} = state, player_tile) do
    {row, col} = case spawn_coordinates do
                    []     -> {round(:math.fmod(player_tile.row, state.state_values.height)),
                               round(:math.fmod(player_tile.col, state.state_values.width))}
                    coords -> Enum.random(coords)
                 end
    spawn_location = Instances.get_map_tile(state, %{row: row, col: col})
    z_index = if spawn_location, do: spawn_location.z_index + 1, else: 0
    %{row: row, col: col, z_index: z_index}
  end

  defp _relocated_coordinates(%Instances{passage_exits: passage_exits} = state, player_tile, passage, passage_match_key) do
    matched_exits = if is_nil(passage_match_key),
                         do:   passage_exits,
                         else: Enum.filter(passage_exits, fn {_id, match_key} -> match_key == passage_match_key end)
    case Enum.map(matched_exits, fn {id, _} -> id end) do
      [] ->
        _relocated_coordinates(state, player_tile)

      exit_ids ->
        passage_exit_id =\
        if length(exit_ids) > 1 do
          Enum.reject(exit_ids, fn id ->
            Map.take(Instances.get_map_tile_by_id(state, %{id: id}) || %{}, [:row, :col]) == Map.take(passage, [:row, :col])
          end)
          |> Enum.random()
        else
          Enum.random(exit_ids)
        end

        spawn_location = Instances.get_map_tile_by_id(state, %{id: passage_exit_id})
        top_tile = Instances.get_map_tile(state, spawn_location)
        z_index = if top_tile, do: top_tile.z_index + 1, else: 0
        %{row: spawn_location.row, col: spawn_location.col, z_index: z_index}
    end
  end
end

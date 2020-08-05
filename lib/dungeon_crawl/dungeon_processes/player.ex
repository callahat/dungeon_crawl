defmodule DungeonCrawl.DungeonProcesses.Player do
  alias DungeonCrawl.Player
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
    {player_tile, state} = Instances.update_map_tile_state(state, player_tile, %{health: 0, gems: 0, cash: 0, ammo: 0, buried: true, deaths: deaths})

    script = """
             :TOP
             #END
             :TOUCH
             #IF not ?sender@player, TOP
             You defile the grave
             #{items_stolen}
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
  def respawn(%Instances{spawn_coordinates: spawn_coordinates} = state, player_tile) do
    {row, col} = Enum.random(spawn_coordinates)
    spawn_location = Instances.get_map_tile(state, %{row: row, col: col})
    z_index = if spawn_location, do: spawn_location.z_index + 1, else: 0

    {player_tile, state} = Instances.update_map_tile(state, player_tile, %{row: row, col: col, z_index: z_index})
    Instances.update_map_tile_state(state, player_tile, %{health: 100, buried: false})
  end
end

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
    keys = tile.parsed_state
           |> Map.to_list
           |> Enum.filter(fn {k,v} -> Regex.match?(~r/_key$/, to_string(k)) && v && v > 0 end)
           |> Enum.map(fn {k,v} -> {String.replace_suffix(to_string(k), "_key",""), v} end)
           |> Enum.map(fn {color, count} ->
                num = if count > 1, do: "<span class='smaller'>x#{count}</span>", else: ""
                "<pre class='tile_template_preview'><span style='color: #{color};'>♀</span>#{num}</pre>"
              end)
           |> Enum.join("")

    Map.take(tile.parsed_state, [:health, :gems, :cash, :ammo])
    |> Map.put(:keys, keys)
  end
end

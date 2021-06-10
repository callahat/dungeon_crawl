defmodule DungeonCrawl.DungeonProcesses.Render do
  @moduledoc """
  This module handles rendering of tile updates.
  """

  alias DungeonCrawl.Admin
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Scripting.Shape

  @doc """
  Handles rerending tiles. It returns a %Levels{} struct.
  Tile updates are stored in a Map with `%{row: _, col: _}` keys in the `rerender_coords` field.

  There are three main scenarios this function handles.

  1. When the level has `visibility: fog` set, it will handle updating the visible area for each player
     and broadcasting to the player's channel tile updates which include tiles that may
     no longer be visible (ie, returned to fog) as well as those that have changed within
     their sight. This will update the %Levels{} player_visible_coords value.
  2. When no tiles have changed since the last call of this function, then nothing is done.
  3. When it is not foggy, then either a full rerender (when the number of rerender coordinates
     is past a threshold) or partial rerender (when only the changed tiles need updated) will occur.
     The new tiles to be displayed on the client will be broadcast via both the dungeon channel
     and the dungeon_admin channel.
  4. Fog range defaults to 6 tiles. It can be set to something else via the `fog_range` state value.
  """
  def rerender_tiles(%Levels{full_rerender: true} = state) do
    full_rerender(state, ["level:#{state.dungeon_instance_id}:#{state.instance_id}",
                          "level_admin:#{state.dungeon_instance_id}:#{state.instance_id}"])
    rerender_tiles(%{state | full_rerender: false})
  end
  def rerender_tiles(%Levels{state_values: %{visibility: "fog"}} = state) do
    state.player_locations
    |> Enum.reduce(state, fn {player_tile_id, location}, state ->
         visible_tiles_for_player(state, player_tile_id, location.id)
       end)
  end
  def rerender_tiles(%Levels{ rerender_coords: coords } = state ) when coords == %{}, do: state
  def rerender_tiles(%Levels{} = state) do
    if length(Map.keys(state.rerender_coords)) > _full_rerender_threshold() do
      full_rerender(state, ["level:#{state.dungeon_instance_id}:#{state.instance_id}",
                            "level_admin:#{state.dungeon_instance_id}:#{state.instance_id}"])
    else
      partial_rerender(state, ["level:#{state.dungeon_instance_id}:#{state.instance_id}",
                               "level_admin:#{state.dungeon_instance_id}:#{state.instance_id}"])
    end

    state
  end

  defp _full_rerender_threshold() do
    if threshold = Application.get_env(:dungeon_crawl, :full_rerender_threshold) do
      threshold
    else
      threshold = Admin.get_setting().full_rerender_threshold || 50
      Application.put_env(:dungeon_crawl, :full_rerender_threshold, threshold)
      threshold
    end
  end

  @doc """
  Handles rerending tiles. It returns a %Levels{} struct.
  Tile updates are stored in a Map with `%{row: _, col: _}` keys in the `rerender_coords` field.

  This function exists due to foggy conditions. When there is fog, the function above will not broadcast
  to the dungeon_admin channel, so this function behaves similar to the 3rd point from above, but
  only will broadcast to the dungeon_admin channel.
  """
  def rerender_tiles_for_admin(%Levels{rerender_coords: coords} = state ) when coords == %{}, do: state
  def rerender_tiles_for_admin(%Levels{state_values: %{visibility: "fog"}} = state) do
    if length(Map.keys(state.rerender_coords)) > _full_rerender_threshold() do
      full_rerender(state, ["level_admin:#{state.dungeon_instance_id}:#{state.instance_id}"])
    else
      partial_rerender(state, ["level_admin:#{state.dungeon_instance_id}:#{state.instance_id}"])
    end

    state
  end
  def rerender_tiles_for_admin(%Levels{} = state), do: state

  @doc """
  Broadcasts a full rerender of all the level tiles to the given channels.
  """
  def full_rerender(%Levels{} = state, channels) do
    level_table = DungeonCrawlWeb.SharedView.level_as_table(state, state.state_values[:rows], state.state_values[:cols])
    Enum.each(channels, fn channel ->
      DungeonCrawlWeb.Endpoint.broadcast channel,
                                         "full_render",
                                         %{level_render: level_table}
    end)
  end

  @doc """
  Broadcasts a rerender of all the level tiles that are in `rerender_coords` to the given channels.
  """
  def partial_rerender(%Levels{} = state, channels) do
      tile_changes = \
      state.rerender_coords
      |> Map.keys
      |> Enum.map(fn coord ->
           tile = Levels.get_tile(state, coord)
           Map.put(coord, :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
         end)
      payload = %{tiles: tile_changes}
    Enum.each(channels, fn channel ->
      DungeonCrawlWeb.Endpoint.broadcast(channel, "tile_changes", payload)
    end)
  end

  @doc """
  Calculates tile changes for a player in a foggy level. This function uses `rerender_coords` as well as
  the player's previous area of vision to determine any updates to broadcast to the player's channel.
  Additionally, it updates the player's visible coordinates and adds that update to the returned instance
  state struct.
  """
  def visible_tiles_for_player(%Levels{state_values: %{visibility: "fog"}} = state, player_tile_id, location_id) do
    visible_coords = state.players_visible_coords[player_tile_id] || []
    player_tile = Levels.get_tile_by_id(state, %{id: player_tile_id})

    if player_tile && _should_update_visible_tiles(visible_coords, state.rerender_coords) do
      range = if player_tile.parsed_state[:buried] == true, do: 0, else: state.state_values[:fog_range] || 6 # get this from the player?
      current_visible_coords = Shape.circle(%{state: state, origin: player_tile}, range, true, "once", 0.33)
                               |> Enum.map(fn {row, col} -> %{row: row, col: col} end)
      fogged_coords = visible_coords -- current_visible_coords
      newly_visible_coords = current_visible_coords -- visible_coords
      rerender_coords = Map.keys(state.rerender_coords)
      renderable_coords = rerender_coords -- (rerender_coords -- current_visible_coords)
      visible_tiles = (renderable_coords ++ newly_visible_coords)
                      |> Enum.uniq()
                      |> Enum.map(fn coord ->
                           tile = Levels.get_tile(state, coord)
                           Map.put(coord, :rendering, DungeonCrawlWeb.SharedView.tile_and_style(tile))
                         end)
      DungeonCrawlWeb.Endpoint.broadcast("players:#{location_id}", "visible_tiles", %{tiles: visible_tiles, fog: fogged_coords})
      %{ state | players_visible_coords: Map.put(state.players_visible_coords, player_tile_id, current_visible_coords) }
    else
      state
    end
  end
  def visible_tiles_for_player(%Levels{} = state, _player_tile_id, _location_id), do: state

  defp _should_update_visible_tiles([], _rerender_coords), do: true
  defp _should_update_visible_tiles(visible_coords, rerender_coords) do
    Map.keys(rerender_coords)
    |> Enum.any?(fn coord -> Enum.member?(visible_coords, coord) end)
  end
end

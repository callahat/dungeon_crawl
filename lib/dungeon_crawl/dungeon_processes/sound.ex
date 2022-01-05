defmodule DungeonCrawl.DungeonProcesses.Sound do
  @moduledoc """
  This module handles directing sound messages to places such as the player channels
  and dungeon admin channels.
  """

  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Scripting.{Shape}

  @doc """
  Handles broadcasting sound effects. It returns a %Levels{} struct with the `sound_effects` key cleared.

  """
  def broadcast_sound_effects(%Levels{sound_effects: sound_effects} = state) do
    _broadcast_sound_effect(sound_effects, %{state | sound_effects: []})
  end

  defp _broadcast_sound_effect([], state), do: state
  defp _broadcast_sound_effect([%{target: "all"} = sound_effect | sound_effects], state) do
    _broadcast_for_admin(state, sound_effect)

    state.player_locations
    |> Enum.each(fn({_tile_id, location}) -> _broadcast_for_player(location.id, sound_effect) end)

    _broadcast_sound_effect(sound_effects, state)
  end
  defp _broadcast_sound_effect([%{target: "nearby"} = sound_effect | sound_effects], state) do
    _broadcast_for_admin(state, sound_effect)

    earshot_blob = Shape.blob_with_range({state, sound_effect}, 15) # 15 is a hardcoded, and the max for hearing other players speak

    state.player_locations
    |> Enum.each(fn({tile_id, location}) ->
         player_tile = Levels.get_tile_by_id(state, %{id: tile_id})
         earshot_square = Enum.find(earshot_blob, fn {row, col, _} -> {row, col} == {player_tile.row, player_tile.col} end)
         if player_tile && earshot_square do
           {_row, _col, distance} = earshot_square
           modifier = max((16 - distance) / 15.0, 0)
           _broadcast_for_player(location.id, sound_effect, modifier)
         end
       end)

    _broadcast_sound_effect(sound_effects, state)
  end
  defp _broadcast_sound_effect([%{target: tile_id} = sound_effect | sound_effects], state)
       when is_integer(tile_id) do
    player_location = state.player_locations[tile_id]

    if player_location, do: _broadcast_for_player(player_location.id, sound_effect)

    _broadcast_sound_effect(sound_effects, state)
  end
  defp _broadcast_sound_effect([_ | sound_effects], state) do
    # target was invalid
    _broadcast_sound_effect(sound_effects, state)
  end

  defp _broadcast_for_admin(state, %{zzfx_params: zzfx_params}) do
    DungeonCrawlWeb.Endpoint.broadcast "level_admin:#{state.dungeon_instance_id}:#{state.instance_id}",
                                       "sound_effect",
                                       %{zzfx_params: zzfx_params, volume_modifier: 1}
  end

  defp _broadcast_for_player(location_id, %{zzfx_params: zzfx_params}, modifier \\ 1) do
    DungeonCrawlWeb.Endpoint.broadcast "players:#{location_id}",
                                       "sound_effect",
                                       %{zzfx_params: zzfx_params, volume_modifier: modifier}
  end
end

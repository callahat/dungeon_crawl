defmodule DungeonCrawl.DungeonProcesses.Sound do
  @moduledoc """
  This module handles directing sound messages to places such as the player channels
  and dungeon admin channels.
  """

  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Scripting.{Shape}

  @doc """
  Handles broadcasting sound effects. It returns a %Levels{} struct with the `sound_effects` key cleared.
  """
  def broadcast_sound_effects(%Levels{sound_effects: sound_effects} = state) do
    _collate_sound_effects(%{}, sound_effects, state)
    |> _broadcast()

    %{ state | sound_effects: [] }
  end

  defp _collate_sound_effects(heard_sounds, [], _state), do: heard_sounds
  defp _collate_sound_effects(heard_sounds, [%{target: "all"} = sound_effect | sound_effects], state) do
    _heard_sound_for_admin(heard_sounds, sound_effect, state)
    |> _collate_for_all_players(sound_effect, state)
    |> _collate_sound_effects(sound_effects, state)
  end
  defp _collate_sound_effects(heard_sounds, [%{target: "nearby"} = sound_effect | sound_effects], state) do
    _heard_sound_for_admin(heard_sounds, sound_effect, state)
    |> _collate_for_nearby_players(sound_effect, state)
    |> _collate_sound_effects(sound_effects, state)
  end
  defp _collate_sound_effects(heard_sounds,[%{target: %Location{} = pl} = sound_effect | sound_effects], state) do
    _heard_sound_for_player(heard_sounds, sound_effect, pl.id)
    |> _heard_sound_for_admin(sound_effect, state)
    |> _collate_sound_effects(sound_effects, state)
  end
  defp _collate_sound_effects(heard_sounds, [%{target: tile_id} = sound_effect | sound_effects], state)
       when is_integer(tile_id) do
    player_location = state.player_locations[tile_id]
    _collate_sound_effects(heard_sounds, [%{ sound_effect | target: player_location} | sound_effects], state)
  end
  defp _collate_sound_effects(heard_sounds, [_ | sound_effects], state) do
    # target was invalid
    _collate_sound_effects(heard_sounds, sound_effects, state)
  end

  defp _collate_for_all_players(heard_sounds, sound_effect, state) do
    state.player_locations
    |> Enum.reduce(heard_sounds, fn({_tile_id, location}, hs) ->
         _heard_sound_for_player(hs, sound_effect, location.id)
       end)
  end

  defp _collate_for_nearby_players(heard_sounds, sound_effect, state) do
    earshot_blob = Shape.blob_with_range({state, sound_effect}, 15) # 15 is a hardcoded, and the max for hearing other players speak

    state.player_locations
    |> Enum.reduce(heard_sounds, fn({tile_id, location}, hs) ->
      player_tile = Levels.get_tile_by_id(state, %{id: tile_id})
      earshot_square = Enum.find(earshot_blob, fn {row, col, _} -> {row, col} == {player_tile.row, player_tile.col} end)
      if player_tile && earshot_square do
        {_row, _col, distance} = earshot_square
        modifier = max((16 - distance) / 15.0, 0)
        _heard_sound_for_player(hs, sound_effect, location.id, modifier)
      else
        hs
      end
    end)
  end

  defp _broadcast(heard_sounds) do
    heard_sounds
    |> Enum.each(fn {channel, sounds} ->
         DungeonCrawlWeb.Endpoint.broadcast channel, "sound_effects", %{sound_effects: sounds}
       end)
  end

  defp _heard_sound_for_admin(heard_sounds, %{zzfx_params: zzfx_params}, state) do
    admin_channel = "level_admin:#{state.dungeon_instance_id}:#{state.instance_id}"
    Map.put(
      heard_sounds,
      admin_channel,
      [ %{zzfx_params: zzfx_params, volume_modifier: 1} | (heard_sounds[admin_channel] || []) ]
    )
  end

  defp _heard_sound_for_player(heard_sounds, %{zzfx_params: zzfx_params}, location_id, modifier \\ 1) do
    player_channel = "players:#{location_id}"
    Map.put(
      heard_sounds,
      player_channel,
      [ %{zzfx_params: zzfx_params, volume_modifier: modifier} | (heard_sounds[player_channel] || []) ]
    )
  end
end

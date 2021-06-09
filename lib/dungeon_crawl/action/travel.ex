defmodule DungeonCrawl.Action.Travel do
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Player
  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Player.Location

  @moduledoc """
  Handles when a player moves from level to level in a dungeon.
  """

  @doc """
  Moves from one level to another. The player characters tile will be removed from the source
  instance and put into the target instance. The location in the target instance will be one of
  the spawn tiles (if any exist on the target level), otherwise the location will be choosen at random
  from a floor space.
  """
  # TODO: this should probably not be called in a blocking manner; could run into a lock where A is moving to Map B, and B is moving to Map A
  # maybe wrap passage and the Levels.run_with from the caller
  # Probably not practical to do when running from the context of the script Runner. Maybe have a way to defer transport when something is blocked.
  # 1. can the change be sent as a message to be executed later when the other instance is not blcoked? Is this actually goign to be a problem?
  # try do
  #   passage
  # catch
  #   :exit, _value -> sleep very short random time, then try again
  # end
  def passage(%Location{} = player_location, %{match_key: _} = passage, level_number, %Levels{} = state) do
    target_level = DungeonInstances.get_level(state.dungeon_instance_id, level_number)

    _passage(player_location, passage, target_level, state)
  end

  def passage(%Location{} = player_location, %{adjacent_level_id: adjacent_level_id, edge: _} = passage, %Levels{} = state) do
    target_level = DungeonInstances.get_level(adjacent_level_id)

    _passage(player_location, passage, target_level, state)
  end

  defp _passage(player_location, passage, target_level, state) do
    player_tile = Levels.get_tile_by_id(state, %{id: player_location.tile_instance_id})
    cond do
      is_nil(target_level)->
        {:ok, state}

      player_tile.level_instance_id == target_level.id ->
        {_player_tile, state} = Player.place(state, player_tile, player_location, passage)
        {:ok, state}

      true ->
        {:ok, dest_instance} = Registrar.instance_process(target_level.dungeon_instance_id, target_level.id)
        LevelProcess.run_with(dest_instance, fn (other_instance_state) ->
          {updated_tile, other_instance_state} = Player.place(other_instance_state, player_tile, player_location, passage)

          level_table = DungeonCrawlWeb.SharedView.level_as_table(other_instance_state, target_level.height, target_level.width)
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "change_level",
                                             %{level_id: target_level.id, level_render: level_table}
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "stat_update",
                                             %{stats: Player.current_stats(other_instance_state, updated_tile)}

          DungeonInstances.update_tiles([Tile.changeset(player_tile, Elixir.Map.take(updated_tile, [:level_instance_id, :row, :col, :z_index]))])

          {:ok, other_instance_state}
        end)

        {_, state} = Levels.delete_tile(state, player_tile, false)

        {:ok, state}
    end
  end
end

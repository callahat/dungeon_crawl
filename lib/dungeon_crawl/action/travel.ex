defmodule DungeonCrawl.Action.Travel do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Player
  alias DungeonCrawl.DungeonProcesses.MapSets
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Player.Location

  @moduledoc """
  Handles when a player moves from map to map in a dungeon.
  """

  @doc """
  Moves from one map to another. The player characters tile will be removed from the source
  instance and put into the target instance. The location in the target instance will be one of
  the spawn tiles (if any exist on the target map), otherwise the location will be choosen at random
  from a floor space.
  """
  # TODO: this should probably not be called in a blocking manner; could run into a lock where A is moving to Map B, and B is moving to Map A
  # maybe wrap passage and the Instances.run_with from the caller
  # Probably not practical to do when running from the context of the script Runner. Maybe have a way to defer transport when something is blocked.
  # 1. can the change be sent as a message to be executed later when the other instance is not blcoked? Is this actually goign to be a problem?
  # try do
  #   passage
  # catch
  #   :exit, _value -> sleep very short random time, then try again
  # end
  def passage(%Location{} = player_location, %{match_key: _} = passage, level_number, %Instances{} = state) do
    target_map = DungeonInstances.get_map(state.map_set_instance_id, level_number)

    _passage(player_location, passage, target_map, state)
  end

  def passage(%Location{} = player_location, %{adjacent_map_id: adjacent_map_id, edge: _} = passage, %Instances{} = state) do
    target_map = DungeonInstances.get_map(adjacent_map_id)

    _passage(player_location, passage, target_map, state)
  end

  defp _passage(player_location, passage, target_map, state) do
    player_map_tile = Instances.get_map_tile_by_id(state, %{id: player_location.map_tile_instance_id})
    cond do
      is_nil(target_map)->
        {:ok, state}

      player_map_tile.map_instance_id == target_map.id ->
        {_player_map_tile, state} = Player.place(state, player_map_tile, player_location, passage)
        {:ok, state}

      true ->
        {:ok, dest_instance} = MapSets.instance_process(target_map.map_set_instance_id, target_map.id)
        InstanceProcess.run_with(dest_instance, fn (other_instance_state) ->
          {updated_tile, other_instance_state} = Player.place(other_instance_state, player_map_tile, player_location, passage)

          dungeon_table = DungeonCrawlWeb.SharedView.dungeon_as_table(other_instance_state, target_map.height, target_map.width)
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "change_dungeon",
                                             %{dungeon_id: target_map.id, dungeon_render: dungeon_table}
          DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                             "stat_update",
                                             %{stats: Player.current_stats(other_instance_state, updated_tile)}

          DungeonInstances.update_map_tiles([MapTile.changeset(player_map_tile, Elixir.Map.take(updated_tile, [:map_instance_id, :row, :col, :z_index]))])

          {:ok, other_instance_state}
        end)

        {_, state} = Instances.delete_map_tile(state, player_map_tile, false)

        {:ok, state}
    end
  end
end

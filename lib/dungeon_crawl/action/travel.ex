defmodule DungeonCrawl.Action.Travel do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Player
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.Map
  alias DungeonCrawl.DungeonInstances.MapTile
#  alias DungeonCrawl.Player
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
  # try do
  #   passage
  # catch
  #   :exit, _value -> sleep very short random time, then try again
  # end
  def passage(%Location{} = player_location, level_number, %Instances{} = state) do
    player_map_tile = DungeonCrawl.Repo.preload(player_location, :map_tile).map_tile

    target_map = DungeonInstances.get_map(state.map_set_instance_id, level_number)

    if player_map_tile.map_instance_id == target_map.id do
      {_player_map_tile, state} = Player.place(state, player_map_tile, player_location)
      {:ok, state}
    else
      {:ok, dest_instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, target_map.id)
      InstanceProcess.run_with(dest_instance, fn (other_instance_state) ->
        {updated_tile, other_instance_state} = Player.place(other_instance_state, player_map_tile, player_location)

        DungeonInstances.update_map_tiles([MapTile.changeset(player_map_tile, Elixir.Map.take(updated_tile, [:map_instance_id, :row, :col, :z_index]))])

        {:ok, other_instance_state}
      end)

      dungeon_table = DungeonCrawlWeb.SharedView.dungeon_as_table(target_map, target_map.height, target_map.width)
      DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}",
                                         "change_dungeon",
                                         %{dungeon_id: target_map.id, dungeon_render: dungeon_table}

      {_, state} = Instances.delete_map_tile(state, player_map_tile, false)

      top_tile = Instances.get_map_tile(state, player_map_tile)
      gone_player = Elixir.Map.put(Elixir.Map.take(top_tile, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(top_tile))
      DungeonCrawlWeb.Endpoint.broadcast "dungeons:#{state.instance_id}",
                                         "tile_changes",
                                         %{tiles: [gone_player]}

      {:ok, state}
    end
    # get instance process for target, run with and place the location there

    # remove player tile from 'state' - this is the old location if state and destination instance are different. if same, do nothing

    # if different, message through the player's channel to leave dungeon channel, load new dungeon table rendering, and join new dungeon channel

  end
end

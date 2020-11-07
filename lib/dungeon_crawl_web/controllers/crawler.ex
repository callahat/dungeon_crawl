defmodule DungeonCrawlWeb.Crawler do
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo

  @moduledoc """
  Useful methods dealing with crawling.
  """

  @doc """
  Join an existing dungeon instance, or creates a new instance to join, and broadcasts the event to the channel.

  ## Examples

      iex> join_and_broadcast(dungeon, "imahash")
      %Player.Location{}

      iex> join_and_broadcast(instance, "imahash")
      %Player.Location{}
  """
  def join_and_broadcast(%DungeonInstances.MapSet{} = where, user_id_hash) do
    {:ok, location} = Player.create_location_on_spawnable_space(where, user_id_hash)
     _broadcast_join_event(location)

     location
  end

  def join_and_broadcast(%Dungeon.MapSet{} = where, user_id_hash, is_private) do
    {:ok, %{map_set: map_set_instance}} = DungeonInstances.create_map_set(where, is_private)

    # ensure all map instances are running
    Repo.preload(map_set_instance, :maps).maps
    |> Enum.each(fn(map_instance) -> InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_instance.id) end)

    join_and_broadcast(map_set_instance, user_id_hash)
  end

  defp _broadcast_join_event(location) do
    map_tile = Repo.preload(location, :map_tile).map_tile
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)

    InstanceProcess.run_with(instance, fn (instance_state) ->
      {top, instance_state} = Instances.create_player_map_tile(instance_state, map_tile, location)
      tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top), else: ""
#    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
#                                    "player_joined",
#                                    %{row: top.row, col: top.col, tile: tile})
      DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{map_tile.map_instance_id}",
                                      "tile_changes",
                                      %{ tiles: [%{row: top.row, col: top.col, rendering: tile}] })
      {tile, instance_state}
    end)
  end

  @doc """
  The given player location leaves a dungeon instance and broadcast the event to the channel.

  ## Examples

      iex> leave_and_broadcast(instance, player_location)
      %Player.Location{}
  """
  def leave_and_broadcast(%Player.Location{} = location) do
    map_tile = Repo.preload(location, :map_tile).map_tile
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    deleted_location = InstanceProcess.run_with(instance, fn (instance_state) ->
      player_tile = Instances.get_map_tile_by_id(instance_state, map_tile)
      {_junk_pile, instance_state} = PlayerInstance.drop_all_items(instance_state, player_tile)
      {deleted_instance_location, instance_state} = Instances.delete_map_tile(instance_state, map_tile)

      deleted_location = Player.delete_location!(location)

      _broadcast_leave_event(instance_state, deleted_instance_location)

      {deleted_location, instance_state}
    end)

    if Player.players_in_dungeon(%{instance_id: deleted_location.map_tile.map_instance_id}) == 0 do
      InstanceRegistry.remove(DungeonInstanceRegistry, deleted_location.map_tile.map_instance_id)
    end

    deleted_location
  end

  defp _broadcast_leave_event(instance_state, map_tile) do
    top = Instances.get_map_tile(instance_state, map_tile)
    tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top), else: ""
#    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{map_tile.map_instance_id}",
#                                    "player_left",
#                                    %{row: map_tile.row, col: map_tile.col, tile: tile})
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{map_tile.map_instance_id}",
                                    "tile_changes",
                                    %{ tiles: [%{row: map_tile.row, col: map_tile.col, rendering: tile}] })

  end
end

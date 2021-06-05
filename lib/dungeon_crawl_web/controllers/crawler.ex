defmodule DungeonCrawlWeb.Crawler do
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.MapSets
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.Player
  alias DungeonCrawl.Repo

  @moduledoc """
  Useful methods dealing with crawling.
  """

  @doc """
  Join an existing dungeon instance, or creates a new instance to join, and broadcasts the event to the channel.

  ## Examples

      iex> join_and_broadcast(dungeon, "imahash", %{color: "red"})
      {<map_set_instance_id>, %Player.Location{}}

      iex> join_and_broadcast(instance, "imahash", %{color: "red"})
      {<map_set_instance_id>, %Player.Location{}}
  """
  def join_and_broadcast(%DungeonInstances.MapSet{} = where, user_id_hash, user_avatar, _) do
    {:ok, location} = Player.create_location_on_spawnable_space(where, user_id_hash, user_avatar)
     _broadcast_join_event(location)

     {where.id, location}
  end

  def join_and_broadcast(%Dungeons.MapSet{} = where, user_id_hash, user_avatar, is_private) do
    {:ok, %{map_set: map_set_instance}} = DungeonInstances.create_map_set(where, is_private)

    # ensure all map instances are running
    Repo.preload(map_set_instance, :maps).maps
    |> Enum.each(fn(map_instance) -> MapSets.instance_process(map_instance.map_set_instance_id, map_instance.id) end)

    join_and_broadcast(map_set_instance, user_id_hash, user_avatar, is_private)
  end

  defp _broadcast_join_event(location) do
    map_tile = Repo.preload(location, [map_tile: :dungeon]).map_tile
    {:ok, instance} = MapSets.instance_process(map_tile.dungeon.map_set_instance_id, map_tile.dungeon.id)

    InstanceProcess.run_with(instance, fn (instance_state) ->
      {top, instance_state} = Instances.create_player_map_tile(instance_state, map_tile, location)
      tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top), else: ""
#    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{instance_state.map_set_instance_id}:#{location.map_tile.map_instance_id}",
#                                    "player_joined",
#                                    %{row: top.row, col: top.col, tile: tile})
      DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{instance_state.map_set_instance_id}:#{map_tile.map_instance_id}",
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
    msi = Repo.preload(map_tile, [dungeon: [map_set: [:locations, :maps]]]).dungeon.map_set

    {:ok, instance} = MapSets.instance_process(msi.id, map_tile.map_instance_id)

    deleted_location = InstanceProcess.run_with(instance, fn (instance_state) ->
      player_tile = Instances.get_map_tile_by_id(instance_state, map_tile)
      {_junk_pile, instance_state} = PlayerInstance.drop_all_items(instance_state, player_tile)
      {_deleted_instance_location, instance_state} = Instances.delete_map_tile(instance_state, map_tile)

      deleted_location = Player.delete_location!(location)

      {deleted_location, instance_state}
    end)

    deleted_location
  end
end

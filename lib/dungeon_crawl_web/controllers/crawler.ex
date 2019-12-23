defmodule DungeonCrawlWeb.Crawler do
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Instances
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
  def join_and_broadcast(%DungeonInstances.Map{} = where, user_id_hash) do
    {:ok, location} = Player.create_location_on_empty_space(where, user_id_hash)

     _broadcast_join_event(Repo.preload(location, :map_tile))
     location
  end

  def join_and_broadcast(%Dungeon.Map{} = where, user_id_hash) do
    {:ok, run_results} = DungeonInstances.create_map(where)
    instance = run_results[:dungeon]
    join_and_broadcast(instance, user_id_hash)
  end

  # TODO: fix potential race condition
  defp _broadcast_join_event(location) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, location.map_tile.map_instance_id)
    instance_state = InstanceProcess.get_state(instance)

    {top, instance_state} = Instances.create_map_tile(instance_state, location.map_tile)
    InstanceProcess.set_state(instance, instance_state)
    tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top), else: ""
#    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
#                                    "player_joined",
#                                    %{row: top.row, col: top.col, tile: tile})
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
                                    "tile_changes",
                                    %{ tiles: [%{row: top.row, col: top.col, rendering: tile}] })
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
    instance_state = InstanceProcess.get_state(instance)

    {_, instance_state} = Instances.delete_map_tile(instance_state, map_tile)
    InstanceProcess.set_state(instance, instance_state)
    deleted_location = Player.delete_location!(location)

    _broadcast_leave_event(deleted_location)

    if Player.players_in_dungeon(%{instance_id: deleted_location.map_tile.map_instance_id}) == 0 do
      InstanceRegistry.remove(DungeonInstanceRegistry, deleted_location.map_tile.map_instance_id)
    end

    deleted_location
  end

  # TODO: fix potential race condition
  defp _broadcast_leave_event(location) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, location.map_tile.map_instance_id)
    instance_state = InstanceProcess.get_state(instance)
    top = Instances.get_map_tile(instance_state, location.map_tile)
    tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top), else: ""
#    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
#                                    "player_left",
#                                    %{row: location.map_tile.row, col: location.map_tile.col, tile: tile})
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
                                    "tile_changes",
                                    %{ tiles: [%{row: location.map_tile.row, col: location.map_tile.col, rendering: tile}] })

  end
end

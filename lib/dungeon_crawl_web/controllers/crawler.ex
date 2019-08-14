defmodule DungeonCrawlWeb.Crawler do
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
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

     _broadcast_join_event(Repo.preload(location, [map_tile: :tile_template]))
     location
  end

  def join_and_broadcast(%Dungeon.Map{} = where, user_id_hash) do
    {:ok, run_results} = DungeonInstances.create_map(where)
    instance = run_results[:dungeon]
    join_and_broadcast(instance, user_id_hash)
  end

  defp _broadcast_join_event(location) do
    top = Repo.preload(DungeonInstances.get_map_tile(location.map_tile), :tile_template)
    tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top.tile_template), else: ""
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
                                    "player_joined",
                                    %{row: top.row, col: top.col, tile: tile})
  end

  @doc """
  The given player location leaves a dungeon instance and broadcast the event to the channel.

  ## Examples

      iex> leave_and_broadcast(instance, player_location)
      %Player.Location{}
  """
  def leave_and_broadcast(%Player.Location{} = location) do
    deleted_location = Player.delete_location!(location)
    _broadcast_leave_event(deleted_location)
    deleted_location
  end

  defp _broadcast_leave_event(location) do
    top = Repo.preload(DungeonInstances.get_map_tile(location.map_tile), :tile_template)
    tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top.tile_template), else: ""
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
                                    "player_left",
                                    %{row: location.map_tile.row, col: location.map_tile.col, tile: tile})
  end
end

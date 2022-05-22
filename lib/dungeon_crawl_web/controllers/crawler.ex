defmodule DungeonCrawlWeb.Crawler do
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.Registrar
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
      {<dungeon_instance_id>, %Player.Location{}}

      iex> join_and_broadcast(instance, "imahash", %{color: "red"})
      {<dungeon_instance_id>, %Player.Location{}}
  """
  def join_and_broadcast(%DungeonInstances.Dungeon{} = where, user_id_hash, user_avatar, _) do
    location = Player.create_location_on_spawnable_space(where, user_id_hash, user_avatar)
    _broadcast_join_event(location)

    {where.id, location}
  end

  def join_and_broadcast(%Dungeons.Dungeon{} = where, user_id_hash, user_avatar, is_private) do
    {:ok, %{dungeon: dungeon_instance}} = DungeonInstances.create_dungeon(where, is_private, true)

    join_and_broadcast(dungeon_instance, user_id_hash, user_avatar, is_private)
  end

  defp _broadcast_join_event(location) do
    tile = Repo.preload(location, [tile: :level]).tile
    {:ok, instance} = Registrar.instance_process(tile.level)

    LevelProcess.run_with(instance, fn (instance_state) ->
      # "player_joined" could be broadcast here should it be needed for a future feature
      Levels.create_player_tile(instance_state, tile, location)
    end)
  end

  @doc """
  The given player location leaves a level instance and broadcast the event to the channel.

  ## Examples

      iex> leave_and_broadcast(instance, player_location)
      %Player.Location{}
  """
  def leave_and_broadcast(%Player.Location{} = location) do
    tile = Repo.preload(location, [tile: :level]).tile
    di = Repo.preload(tile, [level: [dungeon: [:locations, :levels]]]).level.dungeon

    {:ok, instance} = Registrar.instance_process(tile.level)

    deleted_location = LevelProcess.run_with(instance, fn (instance_state) ->
      player_tile = Levels.get_tile_by_id(instance_state, tile)
      instance_state = Levels.gameover(instance_state, player_tile.id, false, "Gave Up")
      {_junk_pile, instance_state} = PlayerInstance.drop_all_items(instance_state, player_tile)
      {_deleted_instance_location, instance_state} = Levels.delete_tile(instance_state, tile)

      deleted_location = Player.delete_location!(location)

      {deleted_location, instance_state}
    end)

    deleted_location
  end
end

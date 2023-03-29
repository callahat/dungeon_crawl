defmodule DungeonCrawlWeb.Crawler do
  alias DungeonCrawl.Account
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.Games
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
    player_name = Account.get_name(user_id_hash)

    {:ok, %{dungeon: dungeon_instance}} = DungeonInstances.create_dungeon(where, player_name, is_private, true)

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
  Loads a save record, finds or reinitializes the instance, and broadcasts the event
  to the channed
  """
  def load_and_broadcast(save_id, user_id_hash) do
    with {:ok, location} <- Games.load_save(save_id, user_id_hash) do
      _broadcast_join_event(location)
    else
      # maybe this should be handled in the crawler controller, it will definitely need to handle it
      error -> error
    end
  end

  @doc """
  The given player location leaves a level instance and broadcast the event to the channel.

  ## Examples

      iex> leave_and_broadcast(instance, player_location)
      %Player.Location{}
  """
  def leave_and_broadcast(%Player.Location{} = location) do
    tile = Repo.preload(location, [tile: :level]).tile

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

  @doc """
  The given player location leaves a level instance and broadcast the event to the channel.

  ## Examples

      iex> leave_and_broadcast(instance, player_location)
      %Save{}
  """
  def save_and_broadcast(%Player.Location{} = location, saveable, delete_location \\ true) do
    tile = Repo.preload(location, [tile: :level]).tile

    {:ok, instance} = Registrar.instance_process(tile.level)

    LevelProcess.run_with(instance, fn (instance_state) ->
      # different saveable modes may not delete existing saves;
      # this will always be a truthy value, later saveable might be something else
      # such as when multiple saves are allowed or a set number of save slots is allowed
      # If its not saveable, then this function should not have been called
      dungeon = Repo.preload(DungeonInstances.get_dungeon!(instance_state.dungeon_instance_id), [dungeon: :user]).dungeon
      if saveable == true do
        Games.list_saved_games(%{user_id_hash: location.user_id_hash, dungeon_id: dungeon.id})
        |> Enum.each(&Games.delete_save/1)
      end

      seconds = NaiveDateTime.diff(NaiveDateTime.utc_now, location.inserted_at)
      player_tile = Levels.get_tile_by_id(instance_state, tile)
      duration = (player_tile.parsed_state[:duration] || 0) + seconds
      {player_tile, instance_state} = Levels.update_tile_state(instance_state, player_tile, %{duration: duration})

      # Its up to the designer of a dungeon to not have cases where a player could save
      # and take with them items needed for other players to advance or win. A player who saves
      # the game takes all their stuff on their tile with them to come back later.
      {:ok, save} = %{user_id_hash: location.user_id_hash,
                      host_name: Account.get_name(dungeon.user),
                      level_name: "#{ tile.level.number } - #{ tile.level.name }"}
                    |> Map.merge(Map.take(player_tile, [:row, :col, :level_instance_id, :state]))
                    |> Games.create_save()


      if delete_location do
        Player.delete_location!(location.user_id_hash)
        {_deleted_tile, instance_state} = Levels.delete_tile(instance_state, tile)
        {save, instance_state}
      else
        {save, instance_state}
      end
    end)
  end
end

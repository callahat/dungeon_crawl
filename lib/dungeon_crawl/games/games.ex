defmodule DungeonCrawl.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Games.Save
  alias DungeonCrawl.Player
  alias DungeonCrawl.StateValue

  @doc """
  Returns the list of saved_games.

  ## Examples

      iex> list_saved_games(%{user_id_hash: "asdf"})
      [%Save{}, ...]

  """
  def list_saved_games do
    Repo.all(Save)
  end
  def list_saved_games(%{user_id_hash: user_id_hash, dungeon_id: dungeon_id}) do
    Repo.all(from s in _dungeon_saves(dungeon_id),
             where: s.user_id_hash == ^user_id_hash)
  end
  def list_saved_games(%{dungeon_id: dungeon_id}) do
    Repo.all(from s in _dungeon_saves(dungeon_id))
  end
  def list_saved_games(%{user_id_hash: user_id_hash}) do
    Repo.all(from s in Save,
             where: s.user_id_hash == ^user_id_hash)
  end

  defp _dungeon_saves(dungeon_id) do
    from s in Save,
         left_join: l in DungeonInstances.Level,
                on: l.id == s.level_instance_id,
         left_join: di in DungeonInstances.Dungeon,
                on: di.id == l.dungeon_instance_id,
         where: di.dungeon_id == ^dungeon_id
  end

  # TODO: should these live in the DungeonInstances module?
  @doc """
  Returns true if there are saves for this dungeon instance
  """
  def has_saved_games?(%DungeonInstances.Level{dungeon_instance_id: id}) do
    has_saved_games?(id)
  end
  def has_saved_games?(%DungeonInstances.Dungeon{id: id}) do
    has_saved_games?(id)
  end
  def has_saved_games?(dungeon_instance_id) when is_integer(dungeon_instance_id) do
    Repo.exists?(_dungeon_instance_saves(dungeon_instance_id))
  end

  defp _dungeon_instance_saves(di_id) do
    from s in Save,
         left_join: l in DungeonInstances.Level,
         on: l.id == s.level_instance_id,
         where: l.dungeon_instance_id == ^di_id
  end

  @doc """
  Gets a single save.

  Raises `Ecto.NoResultsError` if the Save does not exist.

  ## Examples

      iex> get_save(123)
      %Save{}

      iex> get_save(456)
      nil

  """
  def get_save(id), do: Repo.get(Save, id)
  def get_save(id, user_id_hash), do: Repo.get_by(Save, %{id: id, user_id_hash: user_id_hash})

  @doc """
  Creates a save. Ideally this data should be fresh from the proces as the database
  might not have the most up to date information on the user tile, since syncing is
  expensive and only happens periodically.

  ## Examples

      iex> create_save(%{field: value})
      {:ok, %Save{}}

      iex> create_save(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

      iex> create_save(%{field: value}, %Location{})
      {:ok, %Save{}}
  """
  def create_save(attrs) do
    %Save{}
    |> Save.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a save.

  ## Examples

      iex> update_save(save, %{field: new_value})
      {:ok, %Save{}}

      iex> update_save(save, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_save(%Save{} = save, attrs) do
    save
    |> Save.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Loads a save. The only creates the record in the database, it does
  not handle adding the entry to the level process.

  ## Examples

      iex> load_save(id)
      {:ok, %Location{}}

      iex> load_save(id)
      {:error, <reason>}
  """
  def load_save(id, user_id_hash) do
    save = get_save(id)
    with save when not is_nil(save) <- save,
         save = Repo.preload(save, :player_location),
         true <- save.user_id_hash == user_id_hash || :not_owner,
         player when not is_nil(player) <- Account.get_by_user_id_hash(user_id_hash),
         location when is_nil(location) <- Player.get_location(user_id_hash),
         # database constraint prevents this from being nil
         level_instance = DungeonInstances.get_level(save.level_instance_id) do
      # location; row / col may be different depending on the dungeons load spawn setting
      top_tile = DungeonInstances.get_tile(level_instance.id, save.row, save.col)
      z_index = if top_tile, do: top_tile.z_index + 100, else: 100

      tile =
        Map.take(save, [:row, :col, :level_instance_id, :state])
        |> Map.merge(Map.take(player, [:name, :color, :background_color]))
        |> Map.merge(%{z_index: z_index, character: "@"})
        |> DungeonInstances.create_tile!()

      {:ok, Player.update_location!(save.player_location, %{tile_instance_id: tile.id})}
    else
      tile_instance_id when is_integer(tile_instance_id) ->
        {:error, "Player already in a game"}
      :not_owner ->
        {:error, "Save does not belong to player"}
      _ ->
        cond do
          is_nil(save) ->
            {:error, "Save not found"}
          is_nil(Account.get_by_user_id_hash(save.user_id_hash)) ->
            {:error, "Player not found"}
          true ->
            {:error, "Player already in a game"}
        end
    end
  end

  @doc """
  Converts all saves associated with a dungeon to the latest version.
  Only converts the saves from the version previous to the current active version.
  """
  def convert_saves(%Dungeons.Dungeon{active: true, deleted_at: nil, previous_version_id: pv_id}) do
    previous_dungeon = Dungeons.get_dungeon(pv_id)
                       |> Repo.preload(:saves)

    previous_dungeon.saves
    |> Enum.each(&convert_save(&1, false))

    :ok
  end

  def convert_saves(_) do
    :error
  end

  @doc """
  Converts a save from an older version of the dungeon to the current version.
  Does nothing should the save be for the current dungeon.

    ALLOW THE DUNGEON OWNER - IE THE ONE WHO CREATED THE NEW VERSION - TO UPDATE ALL THE SAVES
    AUTOMATICALLY, STARTING WITH THE OLDEST AND GOING TO NEWEST TO ENSURE AN OLD SAVE DOES
    NOT OVERWRITE NEWER UPDATED STUFF

    ALLOW A NORMAL USER TO UPDATE THEIR OLD VERSION, BUT THEY WILL BE THE HOST SO THAT
    THEIR CONVERSION WILL NOT MESS UP OTHER CURRENT INSTANCES
  """
  def convert_save(%Save{} = save, personal_instance \\ true) do
    save = Repo.preload(save, [:player_location, :dungeon, :level_header, [dungeon_instance: [level_headers: :levels]]])

    with false <- is_nil(save.dungeon.deleted_at),
         current_dungeon = Dungeons.get_current_dungeon(save.dungeon.line_identifier) do
      # IF one is found, will it only be safe to copy forward player
      # specific level differences? Maybe only allow the admin to merge into existing
      # dungeon instance?
      host_name = if personal_instance,
                     do: Account.get_name(save.user_id_hash),
                     else: save.dungeon_instance.host_name

      dungeon_instance = _find_or_create_dungeon_instance(
        current_dungeon,
        host_name,
        save.dungeon_instance.is_private)


      # update the dungeon instance state with the state values for the saved DI state
      combined_dungeon_state = dungeon_instance.state
                               |> Map.merge(save.dungeon_instance.state)
      DungeonInstances.update_dungeon(dungeon_instance, %{state: combined_dungeon_state})

      # at this point, we will at least have all the level headers
      save.dungeon_instance.level_headers
      |> Enum.each(fn level_header ->
        current_v_level_header = DungeonInstances.get_level_header(dungeon_instance.id, level_header.number)
                                 |> Repo.preload(:levels)

        if current_v_level_header.type == level_header.type do
          _handle_level_instance(level_header, current_v_level_header, save.player_location_id)
        end
      end)

      # set level_instance_id to the new one that correlated one
      player_location_id = if save.level_header.type == :solo, do: save.player_location_id, else: nil

      level_instance = DungeonInstances.get_level(dungeon_instance.id, save.level_instance.number, player_location_id)

      if level_instance, do: update_save(save, %{level_instance_id: level_instance.id})

      get_save(save.id)

    else
      _ -> nil
    end
  end

  defp _find_or_create_dungeon_instance(current_dungeon, host_name, is_private) do
    case Repo.get_by(DungeonInstances.Dungeon, %{ dungeon_id: current_dungeon.id, host_name: host_name }) do
      nil ->
        {:ok, %{dungeon: dungeon_instance}} = DungeonInstances.create_dungeon(current_dungeon, host_name, is_private, true)
        dungeon_instance

      dungeon_instance ->
        dungeon_instance
    end
  end

  defp _handle_level_instance(save_level_header, current_level_header, player_location_id) do
    save_level_header.levels
    |> Enum.filter(fn level -> is_nil(level.player_location_id) || level.player_location_id == player_location_id end)
    |> Enum.each(fn level ->
      current_level = DungeonInstances.find_or_create_level(current_level_header, player_location_id)

      # update the current level state
      combined_state = level.state
                       |> Map.merge(current_level.state)
      DungeonInstances.update_level(current_level, %{state: combined_state})

      [new_tiles, deleted_tiles] = DungeonInstances.tile_difference_from_base(level)

      _handle_saves_deleted_tiles(current_level.id, deleted_tiles)

      _handle_saves_new_tiles(current_level.id, new_tiles)
    end)
  end

  defp _handle_saves_deleted_tiles(level_id, deleted_tiles) do
    deleted_tiles
    |> Enum.map(fn t ->
      tile = DungeonInstances.get_tile(level_id, t.row, t.col, t.z_index)
      tile && t.name == tile.name && t.script == tile.script && t.state == tile.state && tile.id
    end)
    |> Enum.filter(&(&1))
    |> Enum.uniq()
    |> DungeonInstances.delete_tiles()
  end

  defp _handle_saves_new_tiles(level_id, new_tiles) do
    new_tiles
    |> Enum.each(fn t ->
      case DungeonInstances.get_tile(level_id, t.row, t.col, t.z_index) do
        nil ->
          Map.merge(Dungeons.copy_tile_fields(t), %{level_instance_id: level_id})
          |> DungeonInstances.create_tile!()
        tile ->
          [DungeonInstances.Tile.changeset(tile, Dungeons.copy_tile_fields(t))]
          |> DungeonInstances.update_tiles()
      end
    end)
  end

  @doc """
  Deletes a save.

  ## Examples

      iex> delete_save(save)
      {:ok, %Save{}}

      iex> delete_save(save)
      {:error, %Ecto.Changeset{}}

  """
  def delete_save(%Save{} = save) do
    location = Repo.preload(save, :player_location).player_location
    if location.tile_instance_id do
      Repo.delete(save)
    else
      Repo.delete(location)
      {:ok, save}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking save changes.

  ## Examples

      iex> change_save(save)
      %Ecto.Changeset{data: %Save{}}

  """
  def change_save(%Save{} = save, attrs \\ %{}) do
    Save.changeset(save, attrs)
  end
end

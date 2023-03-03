defmodule DungeonCrawl.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Games.Save
  alias DungeonCrawl.Player

  @doc """
  Returns the list of saved_games.

  ## Examples

      iex> list_saved_games()
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
  def create_save(attrs, %Player.Location{} = location) do
    Player.set_tile_instance_id(location, nil)

    %{user_id_hash: location.user_id_hash}
    |> Map.merge(Map.take(attrs, [:row, :col, :level_instance_id, :state]))
    |> Map.put(:location_id, location.id)
    |> create_save()
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
  def load_save(id) do
    save = get_save(id)
    with save when not is_nil(save) <- save,
         player when not is_nil(player) <- Account.get_by_user_id_hash(save.user_id_hash),
         location when not is_nil(location) <- Player.get_location(%{id: save.location_id}),
         nil <- location.tile_instance_id,
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

      location = Player.set_tile_instance_id(location, tile.id)

      {:ok, location}
    else
      tile_instance_id when is_integer(tile_instance_id) ->
        {:error, "Player already in a game"}
      _ ->
        cond do
          is_nil(save) ->
            {:error, "Save not found"}
          is_nil(Account.get_by_user_id_hash(save.user_id_hash)) ->
            {:error, "Player not found"}
          true ->
            {:error, "Location not found"}
        end
    end
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
    Repo.delete(save)
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

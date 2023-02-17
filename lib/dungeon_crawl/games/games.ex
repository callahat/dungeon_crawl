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
  alias DungeonCrawl.Player.Location

  @doc """
  Returns the list of saved_games.

  ## Examples

      iex> list_saved_games()
      [%Save{}, ...]

  """
  def list_saved_games do
    Repo.all(Save)
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
  Creates a save.

  ## Examples

      iex> create_save(%{field: value})
      {:ok, %Save{}}

      iex> create_save(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_save(attrs \\ %{}) do
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
  Loads a save.

  ## Examples

      iex> load_save(id)
      {:ok, %Location{}}

      iex> load_save(id)
      {:error, <reason>}
  """
  def load_save(id) do
    with save when not is_nil(save) <- get_save(id),
         player when not is_nil(player) <- Account.get_by_user_id_hash(save.user_id_hash),
         nil <- Player.get_location(save.user_id_hash),
         # database constraint prevents this from being nil
         level_instance = DungeonInstances.get_level(save.level_instance_id) do
      # location; row / col may be different depending on the dungeons load spawn setting
      top_tile = DungeonInstances.get_tile(level_instance.id, save.row, save.col)
      z_index = if top_tile, do: top_tile.z_index + 100, else: 0

      tile =
        Map.take(save, [:row, :col, :level_instance_id])
        |> Map.merge(Map.take(player, [:name, :color, :background_color]))
        |> Map.put(:z_index, z_index)
        |> DungeonInstances.create_tile!()

      Player.create_location(%{user_id_hash: save.user_id_hash, tile_instance_id: tile.id})
    else
      %Location{} ->
        {:error, 'Player already in a game'}
      _ ->
        if is_nil(get_save(id)) do
          {:error, 'Save not found'}
        else
          {:error, 'Player not found'}
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

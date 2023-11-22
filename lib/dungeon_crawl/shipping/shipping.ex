defmodule DungeonCrawl.Shipping do
  @moduledoc """
  The Shipping context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Shipping.Export

  @doc """
  Returns the list of dungeon_exports.

  ## Examples

      iex> list_dungeon_exports()
      [%Export{}, ...]

  """
  def list_dungeon_exports do
    Repo.all(from e in Export, order_by: [desc: :id])
  end

  def list_dungeon_exports(user_id) do
    Repo.all(from e in Export, where: e.user_id == ^user_id, order_by: [desc: :id])
  end

  @doc """
  Gets a single export.

  Raises `Ecto.NoResultsError` if the Export does not exist.

  ## Examples

      iex> get_export!(123)
      %Export{}

      iex> get_export!(456)
      ** (Ecto.NoResultsError)

  """
  def get_export!(id), do: Repo.get!(Export, id)

  @doc """
  Creates a export.

  ## Examples

      iex> create_export(%{field: value})
      {:ok, %Export{}}

      iex> create_export(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_export!(attrs \\ %{}) do
    %Export{}
    |> Export.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates a export.

  ## Examples

      iex> update_export(export, %{field: new_value})
      {:ok, %Export{}}

      iex> update_export(export, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_export(%Export{} = export, attrs) do
    export
    |> Export.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a export.

  ## Examples

      iex> delete_export(export)
      {:ok, %Export{}}

      iex> delete_export(export)
      {:error, %Ecto.Changeset{}}

  """
  def delete_export(%Export{} = export) do
    Repo.delete(export)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking export changes.

  ## Examples

      iex> change_export(export)
      %Ecto.Changeset{data: %Export{}}

  """
  def change_export(%Export{} = export, attrs \\ %{}) do
    Export.changeset(export, attrs)
  end

  alias DungeonCrawl.Shipping.Import

  @doc """
  Returns the list of dungeon_imports.

  ## Examples

      iex> list_dungeon_imports()
      [%Import{}, ...]

  """
  def list_dungeon_imports do
    Repo.all(from i in Import, order_by: [desc: :id])
  end

  def list_dungeon_imports(user_id) do
    Repo.all(from i in Import, where: i.user_id == ^user_id, order_by: [desc: :id])
  end

  @doc """
  Gets a single import.

  Raises `Ecto.NoResultsError` if the Import does not exist.

  ## Examples

      iex> get_import!(123)
      %Import{}

      iex> get_import!(456)
      ** (Ecto.NoResultsError)

  """
  def get_import!(id), do: Repo.get!(Import, id)

  @doc """
  Creates a import.

  ## Examples

      iex> create_import(%{field: value})
      {:ok, %Import{}}

      iex> create_import(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_import!(attrs \\ %{}) do
    %Import{}
    |> Import.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates a import.

  ## Examples

      iex> update_import(import, %{field: new_value})
      {:ok, %Import{}}

      iex> update_import(import, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_import(%Import{} = import, attrs) do
    import
    |> Import.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a import.

  ## Examples

      iex> delete_import(import)
      {:ok, %Import{}}

      iex> delete_import(import)
      {:error, %Ecto.Changeset{}}

  """
  def delete_import(%Import{} = import) do
    Repo.delete(import)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking import changes.

  ## Examples

      iex> change_import(import)
      %Ecto.Changeset{data: %Import{}}

  """
  def change_import(%Import{} = import, attrs \\ %{}) do
    Import.changeset(import, attrs)
  end

  @doc """
  Returns true if the file name is already being imported by a user

  ## Examples

      iex> already_importing?("dungeon.json", 1)
      true

  """
  def already_importing?(file_name, user_id) do
    Repo.exists?(from imp in Import,
                 where: imp.file_name == ^file_name and
                        imp.user_id == ^user_id and
                        imp.status in [:queued, :running])
  end

  @doc """
  Returns true if the dungeon is already being exported by a user

  ## Examples

      iex> already_exporting?(1)
      true

  """
  def already_exporting?(dungeon_id, user_id) do
    Repo.exists?(from exp in Export,
                 where: exp.dungeon_id == ^dungeon_id and
                        exp.user_id == ^user_id and
                        exp.status in [:queued, :running])
  end

  @doc """
  Updates the export or import.

  ## Examples

       iex> update(%Export{}, attrs)
       {:ok, %Export{}}
  """
  def update(%Export{} = export, attrs) do
    update_export(export, attrs)
  end

  def update(%Import{} = import, attrs) do
    update_import(import, attrs)
  end
end

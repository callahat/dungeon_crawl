defmodule DungeonCrawl.TileTemplates do
  @moduledoc """
  The TileTemplates context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.TileTemplates.TileTemplate

  @doc """
  Returns the list of tile_templates.

  ## Examples

      iex> list_tile_templates()
      [%TileTemplate{}, ...]

  """
  def list_tile_templates do
    Repo.all(TileTemplate)
  end

  @doc """
  Gets a single tile_template.

  Raises `Ecto.NoResultsError` if the Tile template does not exist.

  ## Examples

      iex> get_tile_template!(123)
      %TileTemplate{}

      iex> get_tile_template!(456)
      ** (Ecto.NoResultsError)

  """
  def get_tile_template!(id), do: Repo.get!(TileTemplate, id)

  @doc """
  Creates a tile_template.

  ## Examples

      iex> create_tile_template(%{field: value})
      {:ok, %TileTemplate{}}

      iex> create_tile_template(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_tile_template(attrs \\ %{}) do
    %TileTemplate{}
    |> TileTemplate.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tile_template.

  ## Examples

      iex> update_tile_template(tile_template, %{field: new_value})
      {:ok, %TileTemplate{}}

      iex> update_tile_template(tile_template, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_tile_template(%TileTemplate{} = tile_template, attrs) do
    tile_template
    |> TileTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a TileTemplate.

  ## Examples

      iex> delete_tile_template(tile_template)
      {:ok, %TileTemplate{}}

      iex> delete_tile_template(tile_template)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tile_template(%TileTemplate{} = tile_template) do
    Repo.delete(tile_template)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tile_template changes.

  ## Examples

      iex> change_tile_template(tile_template)
      %Ecto.Changeset{source: %TileTemplate{}}

  """
  def change_tile_template(%TileTemplate{} = tile_template) do
    TileTemplate.changeset(tile_template, %{})
  end
end

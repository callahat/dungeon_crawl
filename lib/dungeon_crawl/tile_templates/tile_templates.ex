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
    Repo.all(from t in TileTemplate, where: is_nil(t.deleted_at))
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
  def get_tile_template(id),  do: Repo.get(TileTemplate, id)
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
  def create_tile_template!(attrs \\ %{}) do
    %TileTemplate{}
    |> TileTemplate.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Finds or creates a tile_template; mainly useful for the initial seeds.
  When one is found, the oldest tile_template will be returned (ie, first created)
  to ensure that similar tiles created later are not returned.

  Does not accept attributes of `nil`

  ## Examples

      iex> find_or_create_tile_template(%{field: value})
      {:ok, %TileTemplate{}}

      iex> find_or_create_tile_template(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def find_or_create_tile_template(attrs \\ %{}) do
    case Repo.one(from _attrs_query(attrs), limit: 1, order_by: :id) do
      nil      -> create_tile_template(attrs)
      template -> {:ok, template}
    end
  end

  def find_or_create_tile_template!(attrs \\ %{}) do
    case Repo.one(from _attrs_query(attrs), limit: 1, order_by: :id) do
      nil      -> create_tile_template!(attrs)
      template -> template
    end
  end

  defp _attrs_query(attrs) do
    Enum.reduce(attrs, TileTemplate,
      fn {x,y}, query ->
        field_query = [{x, y}] #dynamic keyword list
        query|>where(^field_query)
      end)
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
  Deletes a TileTemplate. The delete is a soft delete so as to not break anything
  that may currently be referecing this tile tempalte, including MapTiles
  as well as parameters in existing responders.

  ## Examples

      iex> delete_tile_template(tile_template)
      {:ok, %TileTemplate{}}

      iex> delete_tile_template(tile_template)
      {:error, %Ecto.Changeset{}}

  """
  def delete_tile_template(%TileTemplate{} = tile_template) do
    change_tile_template(tile_template)
    |> Ecto.Changeset.put_change(:deleted_at, NaiveDateTime.utc_now)
    |> Repo.update
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tile_template changes.

  ## Examples

      iex> change_tile_template(tile_template)
      %Ecto.Changeset{source: %TileTemplate{}}

  """
  def change_tile_template(%TileTemplate{} = tile_template, changes \\ %{}) do
    TileTemplate.changeset(tile_template, changes)
  end
end

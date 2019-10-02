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
  def list_tile_templates(%DungeonCrawl.Account.User{} = user) do
    Repo.all(from t in TileTemplate,
             where: t.user_id == ^user.id,
             where: is_nil(t.deleted_at))
  end
  def list_tile_templates(:nouser) do
    Repo.all(from t in TileTemplate,
             where: is_nil(t.user_id),
             where: is_nil(t.deleted_at))
  end
  def list_tile_templates() do
    Repo.all(from t in TileTemplate,
             where: is_nil(t.deleted_at))
  end

  @doc """
  Returns a map with two keys; :active and :inactive. Each has a list of tile_templates that
  can be used for designing a dungeon. Note that before activating the dungeon, the inactive tiles
  should be activated.

  ## Examples

      iex> list_placeable_tile_templates(%User{})
      %{active: [%TileTemplate{},...], inactive: [%TileTemplate{},...]}
  """
  def list_placeable_tile_templates(%DungeonCrawl.Account.User{} = user) do
    %{ active: _list_placeable_tile_templates(user.id, true),
       inactive: _list_placeable_tile_templates(user.id, false)}
  end

  defp _list_placeable_tile_templates(user_id, active_or_inactive) do
    Repo.all(from t in TileTemplate,
             where: t.public or t.user_id == ^user_id,
             where: t.active == ^active_or_inactive,
             where: is_nil(t.deleted_at),
             order_by: :id)
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
  Returns a boolean indicating wether or not the given tile template has a next version, or is the most current one.

  ## Examples

      iex> next_version_exists?(%TileTemplate{})
      true

      iex> next_version_exists?(%TileTemplate{})
      false
  """
  def next_version_exists?(%TileTemplate{} = template) do
    Repo.one(from t in TileTemplate, where: t.previous_version_id == ^template.id, select: count(t.id)) > 0
  end

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
  Creates a new version of an active tile template. Returns an error if there exists a next version already.

  ## Examples

      iex> create_new_tile_template_version(%TileTemplate{active: true})
      {:ok, %{dungeon: %TileTemplate{}}}

      iex> create_new_tile_template_version(%TileTemplate{active: false})
      {:error, "Inactive tile template"}
  """
  def create_new_tile_template_version(%TileTemplate{active: true} = tile_template) do
    unless next_version_exists?(tile_template) do
      _tile_template_copy_changeset(tile_template)
      |> Repo.insert()
    else
      {:error, "New version already exists"}
    end
  end

  def create_new_tile_template_version(%TileTemplate{active: false}) do
    {:error, "Inactive tile template"}
  end

  defp _tile_template_copy_changeset(tile_template) do
    with old_attrs     <- Elixir.Map.take(tile_template, [:name, :background_color, :character, :color, :user_id, :public, :description, :responders, :state, :script]),
         version_attrs <- %{version: tile_template.version+1, previous_version_id: tile_template.id},
         new_attrs     <- Elixir.Map.merge(old_attrs, version_attrs)
    do
      TileTemplate.changeset(%TileTemplate{}, new_attrs)
    end
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

defmodule DungeonCrawl.DungeonInstances do
  @moduledoc """
  The DungeonInstances context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeon

  alias DungeonCrawl.DungeonInstances.Map
  alias DungeonCrawl.DungeonInstances.MapTile

  @doc """
  Gets a single dungeon instance.

  Raises `Ecto.NoResultsError` if the Map Instance does not exist.

  ## Examples

      iex> get_map!(123)
      %Map{}

      iex> get_map!(456)
      ** (Ecto.NoResultsError)

  """
  def get_map(id),  do: Repo.get(Map, id)
  def get_map!(id), do: Repo.get!(Map, id)


  @doc """
  Creates a dungeon instance.

  ## Examples

      iex> create_map(%Dungeon.Map{})
      {:ok, %DungeonInstances.Map{}}

      iex> create_map(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_map(%Dungeon.Map{} = map) do
    Multi.new()
    |> Multi.insert(:dungeon, Map.changeset(%Map{}, Elixir.Map.merge(%{map_id: map.id}, Elixir.Map.take(map, [:name, :width, :height]))))
    |> Multi.run(:dungeon_map_tiles, fn(%{dungeon: dungeon}) ->
        result = Repo.insert_all(MapTile, _map_tile_instances(dungeon.id, map))
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  defp _map_tile_instances(map_instance_id, %Dungeon.Map{} = map) do
    Repo.preload(map, :dungeon_map_tiles).dungeon_map_tiles
    |> Enum.map(fn(mt) ->
         Elixir.Map.merge(%{map_instance_id: map_instance_id},
                            Elixir.Map.take(mt, [:row, :col, :z_index, :tile_template_id, :character, :color, :background_color, :state])) end)
  end

  @doc """
  Deletes a Dungeon Instance.

  ## Examples

      iex> delete_map(map)
      {:ok, %Map{}}

      iex> delete_map(map)
      {:error, %Ecto.Changeset{}}

  """
  def delete_map(%Map{} = map) do
    Repo.delete(map)
  end
  def delete_map!(%Map{} = map) do
    Repo.delete!(map)
  end

  alias DungeonCrawl.DungeonInstances.MapTile

  @doc """
  Gets a single map_tile, with the highest z_index for given coordinates and dungeon (ie, the tile thats on top)

  Raises `Ecto.NoResultsError` if the Map tile does not exist.

  ## Examples

      iex> get_map_tile!(123)
      %MapTile{}

      iex> get_map_tile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_map_tile!(%{map_instance_id: map_instance_id, row: row, col: col}, direction) do
    {d_row, d_col} = _direction_delta(direction)
    get_map_tile!(map_instance_id, row + d_row, col + d_col)
  end
  def get_map_tile!(%{map_instance_id: map_instance_id, row: row, col: col}), do: get_map_tile!(map_instance_id, row, col)
  def get_map_tile!(id), do: Repo.get!(MapTile, id)
  def get_map_tile!(map_instance_id, row, col, direction), do: get_map_tile!(%{map_instance_id: map_instance_id, row: row, col: col}, direction)
  def get_map_tile!(map_instance_id, row, col) do
    Repo.one!(_get_map_tile_query(map_instance_id, row, col, 1))
  end

  def get_map_tile(%{map_instance_id: map_instance_id, row: row, col: col}, direction) do
    {d_row, d_col} = _direction_delta(direction)
    get_map_tile(map_instance_id, row + d_row, col + d_col)
  end
  def get_map_tile(%{map_instance_id: map_instance_id, row: row, col: col}), do: get_map_tile(map_instance_id, row, col)
  def get_map_tile(map_instance_id, row, col, direction), do: get_map_tile(%{map_instance_id: map_instance_id, row: row, col: col}, direction)
  def get_map_tile(map_instance_id, row, col) do
    Repo.one(_get_map_tile_query(map_instance_id, row, col, 1))
  end

  @doc """
  Returns an array of map tiles from high to low z_index.

  ## Examples

      iex> get_map_tiles(103, 14, 56)
      [%MapTile{}, %MapTile{}, ...]

      iex> get_map_tiles(%{map_instance_id: 103, row: 14, col: 56}, "up")
      []
  """
  def get_map_tiles(%{map_instance_id: map_instance_id, row: row, col: col}, direction) do
    {d_row, d_col} = _direction_delta(direction)
    get_map_tiles(map_instance_id, row + d_row, col + d_col)
  end
  def get_map_tiles(%{map_instance_id: map_instance_id, row: row, col: col}), do: get_map_tiles(map_instance_id, row, col)
  def get_map_tiles(map_instance_id, row, col, direction), do: get_map_tiles(%{map_instance_id: map_instance_id, row: row, col: col}, direction)
  def get_map_tiles(map_instance_id, row, col) do
    Repo.all(_get_map_tile_query(map_instance_id, row, col, nil))
  end

  defp _direction_delta(direction) do
    case direction do
      "up"    -> {-1,  0}
      "down"  -> { 1,  0}
      "left"  -> { 0, -1}
      "right" -> { 0,  1}
      _       -> { 0,  0}
    end
  end

  defp _get_map_tile_query(map_instance_id, row, col, max_results) do
    from mt in MapTile,
    where: mt.map_instance_id == ^map_instance_id and mt.row == ^row and mt.col == ^col,
    order_by: [desc: :z_index],
    limit: ^max_results
  end

  @doc """
  Creates a map_tile.

  ## Examples

      iex> create_map_tile(%{field: value})
      {:ok, %MapTile{}}

      iex> create_map_tile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_map_tile(attrs \\ %{}) do
    %MapTile{}
    |> MapTile.changeset(attrs)
    |> Repo.insert()
  end
  def create_map_tile!(attrs \\ %{}) do
    %MapTile{}
    |> MapTile.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates a map_tile.

  ## Examples

      iex> update_map_tile(map_tile, %{field: new_value})
      {:ok, %MapTile{}}

      iex> update_map_tile(map_tile, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_map_tile!(%MapTile{} = map_tile, attrs) do
    map_tile
    |> MapTile.changeset(attrs)
    |> Repo.update!
  end

  def update_map_tile(%MapTile{} = map_tile, attrs) do
    map_tile
    |> MapTile.changeset(attrs)
    |> Repo.update
  end

end

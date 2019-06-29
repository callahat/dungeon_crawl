defmodule DungeonCrawl.Dungeon do
  alias Ecto.Multi

  @moduledoc """
  The Dungeon context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.Dungeon.MapTile

  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.TileTemplates.TileSeeder

  @doc """
  Returns the list of dungeons.

  ## Examples

      iex> list_dungeons()
      [%Map{}, ...]

  """
  def list_dungeons do
    Repo.all(Map)
  end

  @doc """
  Returns a list of maps with the dungeons and a count of players in them.
  With `:not_autogenerated`, only returns dungeons that were not autogenerated.

  ## Examples

    iex > list_dungeons_with_player_count()
    [%{dungeon: %Map{}, player_count: 4}, ...]
  """
  def list_dungeons_with_player_count() do
    Repo.all(from m in Map,
             left_join: mi in assoc(m, :map_instances),
             left_join: mt in assoc(mi, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             preload: [map_instances: {mi, locations: pmt}],
             select: %{dungeon_id: m.id, dungeon: m},
             order_by: [m.name])
  end
  def list_dungeons_with_player_count(:not_autogenerated) do
    # Todo: move the counts back here
    Repo.all(from m in Map,
             where: m.autogenerated == ^false,
             left_join: mi in assoc(m, :map_instances),
             left_join: mt in assoc(mi, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             preload: [map_instances: {mi, locations: pmt}],
             select: %{dungeon_id: m.id, dungeon: m},
             order_by: [m.name])
  end

  @doc """
  Gets a single map.

  Raises `Ecto.NoResultsError` if the Map does not exist.

  ## Examples

      iex> get_map!(123)
      %Map{}

      iex> get_map!(456)
      ** (Ecto.NoResultsError)

  """
  def get_map(id),  do: Repo.get(Map, id)
  def get_map!(id), do: Repo.get!(Map, id)

  def get_map_by(attrs), do: Repo.get_by!(Map, attrs)

  @doc """
  Creates a map.

  ## Examples

      iex> create_map(%{field: value})
      {:ok, %Map{}}

      iex> create_map(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_map(attrs \\ %{}) do
    %Map{}
    |> Map.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Autogenerates a map.

  ## Examples

      iex> generate_map(DungeonGenerator, %{field: value})
      {:ok, %Map{}}

      iex> generate_map(DungeonGenerator, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def generate_map(dungeon_generator, attrs \\ %{}) do
    Multi.new
    |> Multi.insert(:dungeon, Map.changeset(%Map{}, attrs) |> Ecto.Changeset.put_change(:autogenerated, true))
    |> Multi.run(:dungeon_map_tiles, fn(%{dungeon: dungeon}) ->
        result = Repo.insert_all(MapTile, _generate_dungeon_map_tiles(dungeon, dungeon_generator))
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  defp _generate_dungeon_map_tiles(dungeon, dungeon_generator) do
    tile_mapping = TileSeeder.basic_tiles()

    dungeon_generator.generate(dungeon.height, dungeon.width)
    |> Enum.to_list
    |> Enum.map(fn({{row,col}, tile}) -> %{dungeon_id: dungeon.id, row: row, col: col, tile_template_id: tile_mapping[tile].id, z_index: 0} end)
  end

  @doc """
  Updates a map.

  ## Examples

      iex> update_map(map, %{field: new_value})
      {:ok, %Map{}}

      iex> update_map(map, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_map(%Map{} = map, attrs) do
    map
    |> Map.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Map.

  ## Examples

      iex> delete_map(map)
      {:ok, %Map{}}

      iex> delete_map(map)
      {:error, %Ecto.Changeset{}}

  """
  def delete_map(%Map{} = map) do
    # The cascade doesn't seem to work down from Map -> MapTile -> locations, so they need deleted manually
    #_delete_player_locations(map)
    Repo.delete(map)
  end
  def delete_map!(%Map{} = map) do
    #_delete_player_locations(map)
    Repo.delete!(map)
  end

  defp _delete_player_locations(%Map{} = map) do
    Multi.new
    |> Multi.run(:locations, fn(_) -> {:ok, Repo.preload(map, :locations).locations |> Enum.map(fn(l) -> Repo.delete(l) end)} end)
    |> Repo.transaction
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking map changes.

  ## Examples

      iex> change_map(map)
      %Ecto.Changeset{source: %Map{}}

  """
  def change_map(%Map{} = map) do
    Map.changeset(map, %{})
  end

  @doc """
  Returns the list of dungeon_map_tiles.

  ## Examples

      iex> list_dungeon_map_tiles()
      [%MapTile{}, ...]

  """
  def list_dungeon_map_tiles do
    Repo.all(MapTile)
  end

  @doc """
  Gets a single map_tile, with the highest z_index for given coordinates

  Raises `Ecto.NoResultsError` if the Map tile does not exist.

  ## Examples

      iex> get_map_tile!(123)
      %MapTile{}

      iex> get_map_tile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_map_tile!(%{dungeon_id: dungeon_id, row: row, col: col}), do: get_map_tile!(dungeon_id, row, col)
  def get_map_tile!(id), do: Repo.get!(MapTile, id)
  def get_map_tile!(dungeon_id, row, col) do
    Repo.one!(_get_map_tile_query(dungeon_id, row, col, 1))
  end

  def get_map_tile(%{dungeon_id: dungeon_id, row: row, col: col}), do: get_map_tile(dungeon_id, row, col)
  def get_map_tile(dungeon_id, row, col) do
    Repo.one(_get_map_tile_query(dungeon_id, row, col, 1))
  end

  @doc """
  Returns an array of map tiles from high to low z_index.

  ## Examples

      iex> get_map_tiles(103, 14, 56)
      [%MapTile{}, %MapTile{}, ...]

      iex> get_map_tiles(%{dungeon_id: 103, row: 14, col: 56})
      []
  """
  def get_map_tiles(%{dungeon_id: dungeon_id, row: row, col: col}), do: get_map_tiles(dungeon_id, row, col)
  def get_map_tiles(dungeon_id, row, col) do
    Repo.all(_get_map_tile_query(dungeon_id, row, col, nil))
  end

  defp _get_map_tile_query(dungeon_id, row, col, max_results) do
    from mt in MapTile,
    where: mt.dungeon_id == ^dungeon_id and mt.row == ^row and mt.col == ^col,
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
  def update_map_tile!(%{dungeon_id: dungeon_id, row: row, col: col}, attrs) do
    update_map_tile!(get_map_tile!(dungeon_id, row, col), attrs)
  end

  def update_map_tile(%MapTile{} = map_tile, attrs) do
    map_tile
    |> MapTile.changeset(attrs)
    |> Repo.update
  end
  def update_map_tile(%{dungeon_id: dungeon_id, row: row, col: col}, attrs) do
    update_map_tile(get_map_tile!(dungeon_id, row, col), attrs)
  end


  @doc """
  Returns the number of MapTile that reference a given tile template.

  ## Examples

      iex> tile_template_reference_count(tile_template)
      4

      iex> tile_template_reference_count(6)
      0

  """
  def tile_template_reference_count(%TileTemplate{} = tile_template) do
    tile_template_reference_count(tile_template.id)
  end
  def tile_template_reference_count(tile_template_id) do
    Repo.one(from mt in MapTile, select: count(mt.id), where: mt.tile_template_id == ^tile_template_id)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking map_tile changes.

  ## Examples

      iex> change_map_tile(map_tile)
      %Ecto.Changeset{source: %MapTile{}}

  """
  def change_map_tile(%MapTile{} = map_tile) do
    MapTile.changeset(map_tile, %{})
  end
end

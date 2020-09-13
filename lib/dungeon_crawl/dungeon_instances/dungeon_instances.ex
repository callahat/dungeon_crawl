defmodule DungeonCrawl.DungeonInstances do
  @moduledoc """
  The DungeonInstances context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeon

  alias DungeonCrawl.DungeonInstances.MapSet
  alias DungeonCrawl.DungeonInstances.Map
  alias DungeonCrawl.DungeonInstances.MapTile


  @doc """
  Gets a single map set instance. Takes a map set, and then copies it into an instance,
  maps and all.

  Raises `Ecto.NoResultsError` if the MapSetInstance does not exist.

  ## Examples

      iex> get_map_set!(123)
      %Map{}

      iex> get_map_set!(456)
      ** (Ecto.NoResultsError)

  """
  def get_map_set(id),  do: Repo.get(MapSet, id)
  def get_map_set!(id), do: Repo.get!(MapSet, id)

  @doc """
  Creates a map set instance, initializing also the maps belonging to that map set.

  ## Examples

      iex> create_map_set(%Dungeon.MapSet{})
      {:ok, %{map_set: %DungeonInstances.MapSet{}, maps: [%DungeonInstances.Map{}, ...]}}
      {:ok, %MapSet{}}

  """
  def create_map_set(%Dungeon.MapSet{} = map_set) do
    map_set_attrs = Elixir.Map.merge(%{map_set_id: map_set.id}, Elixir.Map.take(map_set, [:name, :autogenerated, :state]))
    Multi.new()
    |> Multi.insert(:map_set, MapSet.changeset(%MapSet{}, map_set_attrs))
    |> Multi.run(:maps, fn(_repo, %{map_set: map_instance_set}) ->
        result = Repo.preload(map_set, :dungeons).dungeons
                 |> Enum.map(fn(dungeon) ->
                      {:ok, %{dungeon: dungeon}} = create_map(dungeon, map_instance_set.id)
                      dungeon
                    end)
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  @doc """
  Deletes a Map Set Instance.

  ## Examples

      iex> delete_map_set(map_set)
      {:ok, %Map{}}

  """
  def delete_map_set(%MapSet{} = map_set) do
    Repo.preload(map_set, :maps).maps
    |> Enum.each(fn(map) -> Repo.delete!(map) end)
    Repo.delete!(map_set)
  end

  @doc """
  Gets a single dungeon map instance.

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
      {:ok, %{dungeon: %DungeonInstances.Map{}}}

  """
  def create_map(%Dungeon.Map{} = map, msi_id) do
    dungeon_attrs = Elixir.Map.merge(Elixir.Map.take(map, [:name, :width, :height, :state]),
                                     %{map_set_instance_id: msi_id, map_id: map.id})
    Multi.new()
    |> Multi.insert(:dungeon, Map.changeset(%Map{}, dungeon_attrs))
    |> Multi.run(:dungeon_map_tiles, fn(_repo, %{dungeon: dungeon}) ->
        result = _map_tile_instances(dungeon.id, map)
                 |> Enum.chunk_every(1_000,1_000,[])
                 |> Enum.reduce(0, fn(tiles, acc) ->
                     {count, _} = Repo.insert_all(MapTile, tiles)
                     count + acc
                    end )
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  defp _map_tile_instances(map_instance_id, %Dungeon.Map{} = map) do
    Repo.preload(map, :dungeon_map_tiles).dungeon_map_tiles
    |> Enum.map(fn(mt) ->
         Elixir.Map.merge(%{map_instance_id: map_instance_id},
                            Elixir.Map.take(mt, [:row, :col, :z_index, :tile_template_id, :character, :color, :background_color, :state, :script, :name])) end)
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
  Returns a tuple containing a status atom and either the new map tile that has not been persisted to the database
  (when the attrs are valid), OR returns the invalid changeset.
  This function will be used for Instance processes when a tile is created but will either be saved to the database
  later, or will not be long lived enough to bother persisting further down than the instance process.

  ## Examples

      iex> create_map_tile(%{field: value})
      {:ok, %MapTile{}}

      iex> create_map_tile(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def new_map_tile(attrs \\ %{}) do
    changeset = MapTile.changeset(%MapTile{}, attrs)
    if changeset.valid? do
      {:ok, Elixir.Map.merge(%MapTile{}, changeset.changes)}
    else
      {:error, changeset}
    end
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
  Updates the given map tiles.

  ## Examples

      iex> update_map_tiles([<map tile changeset>, <map tile changeset>, ...])
      {3, nil}

  """
  def update_map_tiles(map_tile_changesets) do
    Multi.new
    |> Multi.run(:map_tile_updates, fn(_repo, %{}) ->
        result = map_tile_changesets
                 |> Enum.chunk_every(1_000,1_000,[])
                 |> Enum.reduce(0, fn(chunked_changesets, acc) ->
                     Enum.reduce(chunked_changesets, 0, fn(map_tile_changeset, acc) ->
                       Repo.update(map_tile_changeset)
                       1 + acc
                      end ) + acc
                    end )
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  @doc """
  Deletes the given map tiles.

  ## Examples

      iex> delete_map_tiles([map_tile_id_1, map_tile_id_2, ...])
      {3, nil}

  """
  def delete_map_tiles(map_tile_ids) do
    from(mt in MapTile, where: mt.id in ^map_tile_ids)
    |> Repo.delete_all()
  end
end

defmodule DungeonCrawl.Dungeon do
  alias Ecto.Multi

  @moduledoc """
  The Dungeon context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.Dungeon.MapTile
  alias DungeonCrawl.Dungeon.SpawnLocation

  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.TileTemplates.TileSeeder

  @doc """
  Returns the list of dungeons.
  If given a user, the list will only contain dungeons owned by that user

  ## Examples

      iex> list_dungeons()
      [%Map{}, ...]

      iex> list_dungeons(user)
      [%Map{}, ...]

  """
  def list_dungeons(%DungeonCrawl.Account.User{} = user) do
    Repo.all(from m in Map,
             where: m.user_id == ^user.id,
             where: is_nil(m.deleted_at))
  end
  def list_dungeons(:soft_deleted) do
    Repo.all(from m in Map,
             where: not(is_nil(m.deleted_at)),
             order_by: [:name, :version])
  end
  def list_dungeons() do
    Repo.all(from m in Map,
             where: is_nil(m.deleted_at))
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
             where: is_nil(m.deleted_at),
             left_join: mi in assoc(m, :map_instances),
             left_join: mt in assoc(mi, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             preload: [:user, map_instances: {mi, locations: pmt}],
             select: %{dungeon_id: m.id, dungeon: m},
             order_by: [m.name, pmt.id])
  end

  @doc """
  Returns a list of maps with the dungeons and a count of players in them.
  With `:not_autogenerated`, only returns dungeons that were not autogenerated.

  ## Examples

    iex > list_dungeons_with_player_count()
    [%{dungeon: %Map{}, player_count: 4}, ...]
  """
  def list_active_dungeons_with_player_count() do
    # Todo: move the counts back here
    Repo.all(from m in Map,
             where: is_nil(m.deleted_at),
             where: m.active == ^true,
             left_join: mi in assoc(m, :map_instances),
             left_join: mt in assoc(mi, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             preload: [:user, map_instances: {mi, locations: pmt}],
             select: %{dungeon_id: m.id, dungeon: m},
             order_by: [m.name, pmt.id])
  end

  @doc """
  Gets the number of instances for the given dungeon.

    ## Examples

    iex > instance_count(%Map{})
    3
  """
  def instance_count(%Map{id: dungeon_id}), do: instance_count(dungeon_id)
  def instance_count(dungeon_id) do
    Repo.one(from instance in DungeonCrawl.DungeonInstances.Map,
               where: instance.map_id == ^dungeon_id,
               group_by: instance.map_id,
               select: count(instance.map_id)) || 0
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

  @doc """
  Returns a tuple containing the lowest z_index and highest z_index values, respectively.

  ## Examples

      iex> get_bounding_z_indexes!(456)
      {0,1}
  """
  def get_bounding_z_indexes(%Map{id: dungeon_id}) do
    get_bounding_z_indexes(dungeon_id)
  end
  def get_bounding_z_indexes(dungeon_id) do
    Repo.one(from mt in MapTile,
             where: mt.dungeon_id == ^dungeon_id,
             select: {min(mt.z_index), max(mt.z_index)})
  end

  @doc """
  Returns list of historic (ie, soft deleted) TileTemplates which are present in the dungeon.
  These not selectable for new dungeon design.

  ## Examples

      iex> list_historic_tile_templates(%Map{})
      [%TileTemplate{}, ...]
  """
  def list_historic_tile_templates(%Map{} = map) do
    Repo.all(from mt in MapTile,
             where: mt.dungeon_id == ^map.id,
             left_join: tt in assoc(mt, :tile_template),
             where: not is_nil(tt.deleted_at),
             distinct: true,
             select: tt)
  end

  @doc """
  Returns a boolean indicating wether or not the given dungeon has a next version, or is the most current one.

  ## Examples

      iex> next_version_exists?(%Map{})
      true

      iex> next_version_exists?(%Map{})
      false
  """
  def next_version_exists?(%Map{} = map), do: Repo.one(from m in Map, where: m.previous_version_id == ^map.id, select: count(m.id)) > 0

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
  Creates a new version of an active map. Returns an error if there exists a next version already.

  ## Examples

      iex> create_new_map_version(%Map{active: true})
      {:ok, %{dungeon: %Map{}}}

      iex> create_new_map_version(%Map{active: false})
      {:error, "Inactive map"}
  """
  def create_new_map_version(%Map{active: true} = map) do
    unless next_version_exists?(map) do
      Multi.new
      |> Multi.insert(:dungeon, _dungeon_copy_changeset(map))
      |> Multi.run(:dungeon_map_tiles, fn(_repo, %{dungeon: dungeon}) ->
          result = Repo.insert_all(MapTile, _new_tile_copies(map, dungeon.id))
          {:ok, result}
        end)
      |> Multi.run(:spawn_locations, fn(_repo, %{dungeon: dungeon}) ->
          result = Repo.insert_all(SpawnLocation, _new_spawn_locations(map, dungeon.id))
          {:ok, result}
        end)
      |> Repo.transaction()
    else
      {:error, "New version already exists"}
    end
  end

  def create_new_map_version(%Map{active: false} = _map) do
    {:error, "Inactive map"}
  end

  defp _dungeon_copy_changeset(map) do
    Map.changeset(%Map{},Elixir.Map.merge(Elixir.Map.take(map, [:name, :width, :height, :user_id]),
                                          %{version: map.version+1, previous_version_id: map.id} ))
  end

  defp _new_tile_copies(previous_dungeon, dungeon_id) do
    Repo.preload(previous_dungeon, :dungeon_map_tiles).dungeon_map_tiles
    |> Enum.map(fn(dmt) -> _new_tile_copy(dmt, dungeon_id) end )
  end

  defp _new_tile_copy(dmt, dungeon_id) do
    Elixir.Map.take(dmt, [:row, :col, :z_index, :tile_template_id, :character, :color, :background_color, :state, :script, :name])
    |> Elixir.Map.put(:dungeon_id, dungeon_id)
  end

  defp _new_spawn_locations(previous_dungeon, dungeon_id) do
    Repo.preload(previous_dungeon, :spawn_locations).spawn_locations
    |> Enum.map(fn(sl) -> %{dungeon_id: dungeon_id, row: sl.row, col: sl.col} end)
  end

  @doc """
  Autogenerates a map.

  ## Examples

      iex> generate_map(DungeonGenerator, %{field: value})
      {:ok, %Map{}}

      iex> generate_map(DungeonGenerator, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def generate_map(dungeon_generator, attrs \\ %{}, to_be_edited \\ false) do
    Multi.new
    |> Multi.insert(:dungeon, Map.changeset(%Map{}, attrs) |> Ecto.Changeset.put_change(:autogenerated, !to_be_edited))
    |> Multi.run(:dungeon_map_tiles, fn(_repo, %{dungeon: dungeon}) ->
        result = Repo.insert_all(MapTile, _generate_dungeon_map_tiles(dungeon, dungeon_generator))
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  defp _generate_dungeon_map_tiles(dungeon, dungeon_generator) do
    tile_mapping = TileSeeder.basic_tiles()

    dungeon_generator.generate(dungeon.height, dungeon.width)
    |> Enum.to_list
    |> Enum.map(fn({{row,col}, tile}) -> %{dungeon_id: dungeon.id,
                                           name: tile_mapping[tile].name,
                                           row: row,
                                           col: col,
                                           tile_template_id: tile_mapping[tile].id,
                                           z_index: 0,
                                           character: tile_mapping[tile].character,
                                           color: tile_mapping[tile].color,
                                           background_color: tile_mapping[tile].background_color,
                                           state: tile_mapping[tile].state,
                                           script: tile_mapping[tile].script} end)
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
    case _update_map(map, attrs) do
      {:ok, updated_map} = result ->
        _adjust_sizing(map, updated_map)
        result
      error_result ->
        error_result
    end
  end

  defp _update_map(%Map{} = map, attrs) do
    map
    |> Map.changeset(attrs)
    |> Repo.update()
  end

  defp _adjust_sizing(map, updated_map) do
    Repo.delete_all(from sl in SpawnLocation,
                    where: sl.dungeon_id == ^updated_map.id,
                    where: sl.col >= ^updated_map.width or sl.row >= ^updated_map.height )
    # probably should just use the main module looking for the space character. Character isn't index, but since it
    # is a seed it should have a low id and be found quick
    empty_tile_template = DungeonCrawl.TileTemplates.TileSeeder.rock_tile()
    # row, col are zero index
    # Crop first
    Repo.delete_all(from dmt in MapTile,
                    where: dmt.dungeon_id == ^updated_map.id,
                    where: dmt.col >= ^updated_map.width or dmt.row >= ^updated_map.height )
    # Empty fill second
    new_dmts = _dim_list_difference(map, updated_map)
               |> Enum.map(fn({row,col}) -> %{dungeon_id: updated_map.id,
                                              name: "",
                                              row: row,
                                              col: col,
                                              tile_template_id: empty_tile_template.id,
                                              z_index: 0,
                                              character: empty_tile_template.character,
                                              color: empty_tile_template.color,
                                              background_color: empty_tile_template.background_color,
                                              state: empty_tile_template.state,
                                              script: empty_tile_template.script} end)
    Repo.insert_all MapTile, new_dmts
  end

  # less efficient to make two lists of dimensions and difference them, but less code than computing
  defp _dim_list_difference(map, updated_map) do
    _dim_list(updated_map.width, updated_map.height) -- _dim_list(map.width, map.height)
  end

  defp _dim_list(width, height) do
    for row <- Enum.to_list(0..height-1) do
      for col <- Enum.to_list(0..width-1) do
        {row, col}
      end
    end
    |> Enum.concat
  end

  @doc """
  Activates a map.

  ## Examples

      iex> activate_map(map)
      {:ok, %Map{}}

      iex> activate_map(map)
      {:error, <error message>}

  """
  def activate_map(%Map{} = map) do
    case _inactive_tiles(map) do
      [] ->
        if map.previous_version_id, do: delete_map!(get_map!(map.previous_version_id))
        update_map(map, %{active: true})

      inactive_tile_list ->
        {:error, "Inactive tiles: #{ Enum.join(_inactive_tiles_error_msgs(inactive_tile_list), ", ") }"}
    end
  end

  defp _inactive_tiles(map) do
    Repo.all(from mt in MapTile,
             where: mt.dungeon_id == ^map.id,
             left_join: tt in assoc(mt, :tile_template),
             where: tt.active == false,
             group_by: tt.id,
             select: [tt.name, tt.id, count(tt.id)])
  end

  defp _inactive_tiles_error_msgs([[name, id, count] | tail]) do
    [ "#{name} (id: #{id}) #{count} times" | _inactive_tiles_error_msgs(tail) ]
  end

  defp _inactive_tiles_error_msgs(_empty), do: []

  @doc """
  Deletes a Map.

  ## Examples

      iex> delete_map(map)
      {:ok, %Map{}}

      iex> delete_map(map)
      {:error, %Ecto.Changeset{}}

  """
  def delete_map(%Map{} = map) do
    change_map(map, %{deleted_at: NaiveDateTime.utc_now |> NaiveDateTime.truncate(:second)})
    |> Repo.update
  end
  def delete_map!(%Map{} = map) do
    change_map(map, %{deleted_at: NaiveDateTime.utc_now |> NaiveDateTime.truncate(:second)})
    |> Repo.update!
  end

  @doc """
  Hard deletes a Map.

  ## Examples

      iex> delete_map(map)
      %Map{}

      iex> delete_map(map)
      :error
  """
  def hard_delete_map!(%Map{} = map) do
    Repo.delete!(map)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking map changes.

  ## Examples

      iex> change_map(map)
      %Ecto.Changeset{source: %Map{}}

  """
  def change_map(%Map{} = map, changes \\ %{}) do
    Map.changeset(map, changes)
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
  Gets a single map_tile, with the highest z_index for given coordinates (if no z_index is given)

  Raises `Ecto.NoResultsError` if the Map tile does not exist.

  ## Examples

      iex> get_map_tile!(123)
      %MapTile{}

      iex> get_map_tile!(456)
      ** (Ecto.NoResultsError)

  """
  def get_map_tile!(%{dungeon_id: dungeon_id, row: row, col: col, z_index: z_index}), do: get_map_tile!(dungeon_id, row, col, z_index)
  def get_map_tile!(%{dungeon_id: dungeon_id, row: row, col: col}), do: get_map_tile!(dungeon_id, row, col)
  def get_map_tile!(id), do: Repo.get!(MapTile, id)
  def get_map_tile!(dungeon_id, row, col, z_index) do
    Repo.one!(_get_map_tile_query(dungeon_id, row, col, z_index, 1))
  end
  def get_map_tile!(dungeon_id, row, col) do
    Repo.one!(_get_map_tile_query(dungeon_id, row, col, 1))
  end

  def get_map_tile(%{dungeon_id: dungeon_id, row: row, col: col, z_index: z_index}), do: get_map_tile(dungeon_id, row, col, z_index)
  def get_map_tile(%{dungeon_id: dungeon_id, row: row, col: col}), do: get_map_tile(dungeon_id, row, col)
  def get_map_tile(dungeon_id, row, col, z_index) do
    Repo.one(_get_map_tile_query(dungeon_id, row, col, z_index, 1))
  end
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

  defp _get_map_tile_query(dungeon_id, row, col, z_index, max_results) do
    from mt in MapTile,
    where: mt.dungeon_id == ^dungeon_id and mt.row == ^row and mt.col == ^col and mt.z_index == ^z_index,
    limit: ^max_results
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

  @doc """
  Deletes a Map Tile. If map tile with the given coords and dungeon does not exist, nil is returned.

  ## Examples

      iex> delete_map_tile(%MapTile{})
      %MapTile{}

      iex> delete_map_tile(dungeon_id, row, col, z_index)
      %MapTile{}

      iex> delete_map(dungeon_id, row, col, z_index)
      nil
  """
  def delete_map_tile(dungeon_id, row, col, z_index) do
    delete_map_tile(get_map_tile(dungeon_id, row, col, z_index))
  end
  def delete_map_tile(nil), do: nil
  def delete_map_tile(%MapTile{} = map_tile) do
    Repo.delete(map_tile)
  end

  @doc """
  Adds spawn locations for the given dungeon. Uses a list of {row, col} tuples to indicate the new
  spawn coordinates. Existing spawn locations as well as invalid coordinates are ignored.

  ## Examples

      iex> add_spawn_locations(%Map{}, [{row, col}, ...])
      [%SpawnLocation{}, ...]
  """
  def add_spawn_locations(dungeon_id, coordinates) do
    dungeon = get_map!(dungeon_id)

    Multi.new
    |> Multi.run(:spawn_locations, fn(_repo, %{}) ->
        locations = coordinates
                    |> Enum.uniq
                    |> Enum.map(fn({row, col}) -> %{dungeon_id: dungeon_id, row: row, col: col} end)
                    |> Enum.reject(fn(attrs) -> Repo.get_by(SpawnLocation, dungeon_id: attrs.dungeon_id, row: attrs.row, col: attrs.col) end) # TODO: remove after pg local updated
                    |> Enum.filter(fn(attrs) ->
                        SpawnLocation.changeset(%SpawnLocation{}, attrs, dungeon.height, dungeon.width).valid?
                       end)
        # result = Repo.insert_all(SpawnLocation, locations, on_conflict: :nothing, conflict_target: "spawn_locations_dungeon_id_row_col_index") # TODO: use after pg local updated
        result = Repo.insert_all(SpawnLocation, locations)
        {:ok, result}
      end)
    |> Repo.transaction()
  end

  @doc """
  Deletes all the spawn locations for the given dungeon.

  ## Examples

      iex> clear_spawn_locations(%Map{}, [{row, col}, ...])
      [%SpawnLocation{}, ...]
  """
  def clear_spawn_locations(dungeon_id) do
    Repo.delete_all(from s in SpawnLocation,
                    where: s.dungeon_id == ^dungeon_id)
  end

  @doc """
  Sets the spawn locations for the given dungeon. Uses a list of {row, col} tuples to indicate the new
  spawn coordinates. Existing spawn locations are first removed, and then the new list is added.

  ## Examples

      iex> set_spawn_locations(%Map{}, [{row, col}, ...])
      [%SpawnLocation{}, ...]
  """
  def set_spawn_locations(dungeon_id, coordinates) do
    clear_spawn_locations(dungeon_id)
    add_spawn_locations(dungeon_id, coordinates)
  end
end

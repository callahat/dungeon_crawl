defmodule DungeonCrawl.Player do
  @moduledoc """
  The Player context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonInstances.{Dungeon, Level, Tile}
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.TileTemplates

  @doc """
  Gets a single location.

  Raises `Ecto.NoResultsError` if the Location does not exist when using the `!` version.

  ## Examples

      iex> get_location!("user_id_hash")
      %Location{}

      iex> get_location!(456)
      ** (Ecto.NoResultsError)

  """
  def get_location(%{id: location_id}), do: Repo.get_by(Location, %{id: location_id})
  def get_location(user_id_hash), do: Repo.get_by(Location, %{user_id_hash: user_id_hash})
  def get_location!(user_id_hash), do: Repo.get_by!(Location, %{user_id_hash: user_id_hash})

  @doc """
  Creates a location.

  ## Examples

      iex> create_location(%{field: value})
      {:ok, %Location{}}

      iex> create_location(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_location(attrs \\ %{}) do
    %Location{}
    |> Location.changeset(attrs)
    |> Repo.insert()
  end
  def create_location!(attrs \\ %{}) do
    %Location{}
    |> Location.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Creates a tile that can be used for player location on an spawn location (if present),
  otherwise falls back to spawning on an empty floor space tile.

  ## Examples

      iex> create_location_on_spawnable_space(%Level{})
      {:ok, %Location{}}
  """
  def create_location_on_spawnable_space(%Dungeon{} = di, user_id_hash, user_avatar) do
    tile = _create_tile_for_location(di, user_id_hash, user_avatar)

    create_location(%{tile_instance_id: tile.id, user_id_hash: user_id_hash})
  end

  defp _create_tile_for_location(%Dungeon{} = di, user_id_hash, user_avatar) do
    instance_levels = Repo.preload(di, levels: [level: :spawn_locations]).levels
    entrance = _entrance(instance_levels) || _random_entrance(instance_levels)
    spawn_location = _spawn_location(entrance) || _random_floor(entrance)
    top_tile = DungeonInstances.get_tile(entrance.id, spawn_location.row, spawn_location.col)
    z_index = if top_tile, do: top_tile.z_index + 100, else: 0

    player_tile_template = TileTemplates.TileSeeder.player_character_tile()

    Map.take(spawn_location, [:row, :col])
    |> Map.merge(%{level_instance_id: entrance.id})
    |> Map.merge(%{z_index: z_index})
    |> Map.merge(TileTemplates.copy_fields(player_tile_template))
    |> Map.merge(%{name: user_avatar["name"], color: user_avatar["color"], background_color: user_avatar["background_color"]})
    |> Map.put(:name, Account.get_name(user_id_hash))
    |> DungeonInstances.create_tile!()
    |> _set_player_lives(di)
  end

  defp _entrance(instance_levels) do
    instance_levels
    |> Enum.filter(fn(level) -> level.level.entrance end)
    |> Enum.shuffle
    |> Enum.at(0)
  end

  defp _random_entrance(instance_levels) do
    Enum.at(Enum.shuffle(instance_levels), 0)
  end

  defp _spawn_location(entrance) do
    entrance.level.spawn_locations
    |> Enum.shuffle
    |> Enum.at(0)
  end

  defp _random_floor(entrance) do
    Repo.preload(entrance, [:tiles]).tiles
    |> Enum.filter(fn(t) -> t.name == "Floor" || t.character == "." end)
    |> Enum.shuffle
    |> Enum.at(0)
  end

  defp _set_player_lives(player_tile, di) do
    {:ok, dungeon_parsed_state} = DungeonCrawl.StateValue.Parser.parse(di.state)
    starting_lives = "lives: #{ dungeon_parsed_state[:starting_lives] || -1 }"

    Repo.update!(Tile.changeset(player_tile, %{state: player_tile.state <> ", " <> starting_lives }))
  end

  @doc """
  Deletes a Location.

  ## Examples

      iex> delete_location!(location)
      %Location{}

      iex> delete_location!(location)
      # Exception raised if bad location

  """
  def delete_location!(%Location{} = location) do
    location = Repo.preload(location, [tile: [level: [dungeon: :dungeon]]])

    Repo.delete!(location.tile)

    location
  end
  def delete_location!(user_id_hash) do
    location = get_location(user_id_hash)
    delete_location!(location)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking location changes.

  ## Examples

      iex> change_location(location)
      %Ecto.Changeset{source: %Location{}}

  """
  def change_location(%Location{} = location, attrs \\ %{}) do
    Location.changeset(location, attrs)
  end

  @doc """
  Returns a count of how many players are in a level

  ## Examples

      iex> player_count(103)
      4
  """
  def players_in_level(%Dungeons.Level{id: level_id}) do
    Repo.one(from m in Dungeons.Level,
             where: m.id == ^level_id,
             left_join: li in assoc(m, :level_instances),
             left_join: t in assoc(li, :tiles),
             left_join: pmt in assoc(t, :player_location),
             select: count(pmt.id))
  end
  def players_in_level(%Level{id: instance_id}) do
    Repo.one(from l in Level,
             where: l.id == ^instance_id,
             left_join: t in assoc(l, :tiles),
             left_join: pmt in assoc(t, :player_location),
             select: count(pmt.id))
  end

  def players_in_level(%{instance_id: instance_id}) do
    players_in_level(%Level{id: instance_id})
  end

  @doc """
  Returns the player locations in a given level instance.
  """
  def players_in_instance(%Level{id: instance_id}) do
    Repo.all(from l in Level,
             left_join: t in assoc(l, :tiles),
             left_join: pmt in assoc(t, :player_location),
             where: l.id == ^instance_id and pmt.tile_instance_id == t.id,
             select: pmt)
  end

  @doc """
  Returns the dungeon of the instance where the player location is.
  Useful for determining if the player is test crawling an unactivated dungeon.

  ## Examples

      iex> get_dungeon(%Location{})
      %Dungeons.Dungeon{}
  """
  def get_dungeon(%Location{} = location) do
    Repo.preload(location, [tile: [level: [dungeon: :dungeon]]]).tile.level.dungeon.dungeon
  end
end

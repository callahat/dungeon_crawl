defmodule DungeonCrawl.Player do
  @moduledoc """
  The Player context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Player.Location

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
  Creates a map tile that can be used for player location on an empty floor space tile.

  ## Examples

      iex> create_location_on_empty_space(%DungeonCrawl.DungeonInstances.Map{})
      {:ok, %Location{}}
  """
  def create_location_on_empty_space(%DungeonCrawl.DungeonInstances.Map{} = instance, user_id_hash) do
    map_tile = _create_map_tile_for_location(instance)

    create_location(%{map_tile_instance_id: map_tile.id, user_id_hash: user_id_hash})
  end

  defp _create_map_tile_for_location(%DungeonCrawl.DungeonInstances.Map{} = instance) do
    empty_floor = Repo.preload(instance, dungeon_map_tiles: :tile_template).dungeon_map_tiles
                      |> Enum.filter(fn(t) -> t.tile_template && t.tile_template.character == "." end)
                      |> Enum.random

    player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()

    Map.take(empty_floor, [:map_instance_id, :row, :col])
    |> Map.merge(%{tile_template_id: player_tile_template.id, z_index: 1})
    |> Map.merge(Map.take(player_tile_template, [:character, :color, :background_color, :state]))
    |> DungeonCrawl.DungeonInstances.create_map_tile!()
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
    location = Repo.preload(location, [map_tile: [dungeon: :dungeon]])

    if location.map_tile.dungeon.dungeon.autogenerated do
      DungeonCrawl.Dungeon.hard_delete_map!(location.map_tile.dungeon.dungeon)
      location
    else
      Repo.delete!(location.map_tile)
      if Repo.one(from l in Location,
                left_join: mt in assoc(l, :map_tile),
                where: mt.map_instance_id == ^location.map_tile.map_instance_id,
                select: count(mt.id)) == 0 do
        DungeonCrawl.DungeonInstances.delete_map!(location.map_tile.dungeon)
      end
      location
    end
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
  Returns a count of how many players are in a dungeon

  ## Examples

      iex> player_count(103)
      4
  """
  def players_in_dungeon(%DungeonCrawl.Dungeon.Map{id: dungeon_id}) do
    Repo.one(from m in DungeonCrawl.Dungeon.Map,
             where: m.id == ^dungeon_id,
             left_join: mi in assoc(m, :map_instances),
             left_join: mt in assoc(mi, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             select: count(pmt.id))
  end
  def players_in_dungeon(%DungeonCrawl.DungeonInstances.Map{id: instance_id}) do
    Repo.one(from m in DungeonCrawl.DungeonInstances.Map,
             where: m.id == ^instance_id,
             left_join: mt in assoc(m, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             select: count(pmt.id))
  end
  # TODO: consolidate
  def players_in_dungeon(%{instance_id: instance_id}) do
    Repo.one(from m in DungeonCrawl.DungeonInstances.Map,
             where: m.id == ^instance_id,
             left_join: mt in assoc(m, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             select: count(pmt.id))
  end

  @doc """
  Returns the player locations in a given dungeon instance.
  """
  def players_in_instance(%DungeonCrawl.DungeonInstances.Map{id: instance_id}) do
    Repo.all(from m in DungeonCrawl.DungeonInstances.Map,
             left_join: mt in assoc(m, :dungeon_map_tiles),
             left_join: pmt in assoc(mt, :player_locations),
             where: m.id == ^instance_id and pmt.map_tile_instance_id == mt.id,
             select: pmt)
  end

  @doc """
  Returns the dungeon of the instance where the player location is.
  Useful for determining if the player is test crawling an unactivated dungeon.

  ## Examples

      iex> get_dungeon(%Location{})
      %Dungeon.Map{}
  """
  def get_dungeon(%Location{} = location) do
    Repo.preload(location, [map_tile: [dungeon: :dungeon]]).map_tile.dungeon.dungeon
  end
end

defmodule DungeonCrawl.DungeonProcesses.Instances do
  @moduledoc """
  The instances context.
  """

  defstruct program_contexts: %{}, map_by_ids: %{}, map_by_coords: %{}

  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry,InstanceProcess}

  @doc """
  Gets the top map tile in the given directon from the provided coordinates.
  """
  def get_map_tile(%{row: row, col: col} = map_tile, direction \\ nil) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.get_tile(instance, row, col, direction)
  end

  @doc """
  Gets the map tiles in the given directon from the provided coordinates.
  """
  def get_map_tiles(%{row: row, col: col} = map_tile, direction \\ nil) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.get_tiles(instance, row, col, direction)
  end

  @doc """
  Gets the map tile given by the id.
  """
  def get_map_tile_by_id(%{id: map_tile_id} = map_tile) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.get_tile(instance, map_tile_id)
  end

  @doc """
  Updates the given map tile in the parent instance process, and returns the updated tile.
  """
  def update_map_tile(map_tile, new_attrs) do
IO.puts "UPDATE MAP TILE"
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
IO.puts "GOT INSTANCE PID"
IO.puts inspect map_tile.map_instance_id
IO.puts inspect map_tile.id
# IO.puts inspect InstanceProcess.get_tile(instance, map_tile.id)
    InstanceProcess.update_tile(instance, map_tile.id, new_attrs)
:timer.sleep 50
IO.puts "instance processed update tile"
#  InstanceProcess.get_tile(instance, map_tile.id)
    map_tile |> Map.merge(new_attrs) |> Map.merge(%{id: map_tile.id})
  end

  @doc """
  Creates the given map tile in the parent instance process if it does not already exist.
  Returns the created (or already existing) tile
  """
  def create_map_tile(map_tile) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.load_map(instance, [map_tile])
    InstanceProcess.get_tile(instance, map_tile.id)
  end

  @doc """
  Deletes the given map tile from the parent instance process.
  """
  def delete_map_tile(map_tile) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.delete_tile(instance, map_tile.id)
  end
end


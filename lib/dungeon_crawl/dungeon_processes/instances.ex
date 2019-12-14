defmodule DungeonCrawl.DungeonProcesses.Instances do
  @moduledoc """
  The instances context. This wraps InstanceRegistry lookups and InstanceProcess methods
  for convenience.
  """

  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry,InstanceProcess}

  @doc """
  Gets the top map tile in the given directon from the provided coordinates.
  """
  def get_map_tile(%{row: row, col: col} = map_tile, direction \\ nil) do
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.get_tile(instance, row, col, direction)
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
    {:ok, instance} = InstanceRegistry.lookup_or_create(DungeonInstanceRegistry, map_tile.map_instance_id)
    InstanceProcess.update_tile(instance, map_tile.id, new_attrs)
    InstanceProcess.get_tile(instance, map_tile.id)
  end
end


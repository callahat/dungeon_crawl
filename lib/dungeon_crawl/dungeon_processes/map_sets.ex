defmodule DungeonCrawl.DungeonProcesses.MapSets do
  alias DungeonCrawl.DungeonProcesses.MapSets
  alias DungeonCrawl.DungeonProcesses.{InstanceRegistry,MapSetRegistry,MapSetProcess}

  @moduledoc """
  Wraps some convenience methods related to Map Set related processes/registries
  and Instance related processes/registries
  """

  @doc """
  Returns the instance process given map set and instance id if found.
  """
  def instance_process(map_set_instance_id, instance_id) do
    with {:ok, instance_registry} <- MapSets.instance_registry(map_set_instance_id),
         {:ok, instance_process} <- InstanceRegistry.lookup_or_create(instance_registry, instance_id) do
      {:ok, instance_process}
    else
      _ -> nil
    end
  end

  @doc """
  Returns the instance registry given the map set if found.
  """
  def instance_registry(map_set_instance_id) do
    with {:ok, map_set_process} <- MapSetRegistry.lookup_or_create(MapSetInstanceRegistry, map_set_instance_id) do
      {:ok, MapSetProcess.get_instance_registry(map_set_process)}
    else
      _ -> nil
    end
  end
end


defmodule DungeonCrawl.DungeonProcesses.Registrar do
  alias DungeonCrawl.DungeonProcesses.{LevelRegistry,DungeonRegistry,DungeonProcess}

  @moduledoc """
  Wraps some convenience methods related to Dungeon related processes/registries
  and Instance related processes/registries
  """

  @doc """
  Returns the instance process given dungeon and instance id if found.
  """
  def instance_process(dungeon_instance_id, level_number, owner_id) do
    with {:ok, instance_registry} <- instance_registry(dungeon_instance_id),
         {:ok, {_iid, instance_process}} <- LevelRegistry.lookup_or_create(instance_registry, level_number, owner_id) do
      {:ok, instance_process}
    else
      _ -> nil
    end
  end
  def instance_process(%{dungeon_instance_id: diid, number: level_number, player_location_id: owner_id}) do
    instance_process(diid, level_number, owner_id)
  end

  @doc """
  Returns the instance registry given the dungeon if found.
  """
  def instance_registry(dungeon_instance_id) do
    with {:ok, map_set_process} <- DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, dungeon_instance_id) do
      {:ok, DungeonProcess.get_instance_registry(map_set_process)}
    else
      _ -> nil
    end
  end
end


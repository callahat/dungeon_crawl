defmodule DungeonCrawlWeb.ManageDungeonInstanceController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.MapSets

  def show(conn, %{"msi_id" => msi_id, "id" => id}) do
    case MapSets.instance_process(String.to_integer(msi_id), String.to_integer(id)) do
      {:ok, instance_process} ->
        instance_state = InstanceProcess.get_state(instance_process)
        instance = Repo.preload(DungeonInstances.get_map(String.to_integer(id)), [dungeon: :map_set])
        render(conn, "show.html", instance_state: instance_state, instance: instance)
      _ ->
        conn
        |> put_flash(:info, "Instance not found: `#{id}`")
        |> redirect(to: Routes.manage_map_set_instance_path(conn, :show, msi_id))
    end
  end

  def delete(conn, %{"msi_id" => msi_id, "id" => id}) do
    case MapSets.instance_registry(String.to_integer(msi_id)) do
      {:ok, instance_registry} -> InstanceRegistry.remove(instance_registry, String.to_integer(id))
      _ -> nil
    end

    conn
    |> put_flash(:info, "Removing instance process with id `#{id}`")
    |> redirect(to: Routes.manage_map_set_instance_path(conn, :show, msi_id))
  end
end

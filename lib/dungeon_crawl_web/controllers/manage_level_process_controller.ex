defmodule DungeonCrawlWeb.ManageLevelProcessController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Registrar

  def show(conn, %{"di_id" => di_id, "id" => id}) do
    case Registrar.instance_process(String.to_integer(di_id), String.to_integer(id)) do
      {:ok, instance_process} ->
        instance_state = LevelProcess.get_state(instance_process)
        instance = Repo.preload(DungeonInstances.get_level(String.to_integer(id)), [level: :dungeon])
        render(conn, "show.html", instance_state: instance_state, instance: instance)
      _ ->
        conn
        |> put_flash(:info, "Level instance process not found: `#{id}`")
        |> redirect(to: Routes.manage_dungeon_process_path(conn, :show, di_id))
    end
  end

  def delete(conn, %{"di_id" => di_id, "id" => id}) do
    case Registrar.instance_registry(String.to_integer(di_id)) do
      {:ok, instance_registry} -> LevelRegistry.remove(instance_registry, String.to_integer(id))
      _ -> nil
    end

    conn
    |> put_flash(:info, "Removing level instance process with id `#{id}`")
    |> redirect(to: Routes.manage_dungeon_process_path(conn, :show, di_id))
  end
end

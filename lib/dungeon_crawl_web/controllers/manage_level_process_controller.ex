defmodule DungeonCrawlWeb.ManageLevelProcessController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Registrar

  def show(conn, %{"di_id" => di_id, "num" => num, "plid" => _plid}) do
    di_id = String.to_integer(di_id)
    num = String.to_integer(num)
    case Registrar.instance_process(di_id, num) do
      {:ok, instance_process} ->
        instance_state = LevelProcess.get_state(instance_process)
        instance = Repo.preload(DungeonInstances.get_level(di_id, num), [level: :dungeon])
        render(conn, "show.html", instance_state: instance_state, instance: instance)
      _ ->
        conn
        |> put_flash(:info, "Level instance process not found: dungeon instance `#{di_id}`, level number `#{num}`")
        |> redirect(to: Routes.manage_dungeon_process_path(conn, :show, di_id))
    end
  end

  def delete(conn, %{"di_id" => di_id, "num" => num, "plid" => _plid}) do
    case Registrar.instance_registry(String.to_integer(di_id)) do
      {:ok, instance_registry} -> LevelRegistry.remove(instance_registry, String.to_integer(num))
      _ -> nil
    end

    conn
    |> put_flash(:info, "Removing level instance process with for dungein instance #{di_id} level number `#{num}`")
    |> redirect(to: Routes.manage_dungeon_process_path(conn, :show, di_id))
  end
end

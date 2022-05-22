defmodule DungeonCrawlWeb.ManageLevelProcessController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.Registrar

  def show(conn, %{"di_id" => di_id, "num" => num, "plid" => plid}) do
    {di_id, num, plid} = _params_to_integers(di_id, num, plid)

    case Registrar.instance_process(di_id, num, plid) do
      {:ok, instance_process} ->
        instance_state = LevelProcess.get_state(instance_process)
        instance = Repo.preload(DungeonInstances.get_level(di_id, num, plid), [level: :dungeon])
        render(conn, "show.html", instance_state: instance_state, instance: instance)
      _ ->
        conn
        |> put_flash(:info, "Level instance process not found: dungeon instance `#{di_id}`, level number `#{num}`, owner id `#{plid}`")
        |> redirect(to: Routes.manage_dungeon_process_path(conn, :show, di_id))
    end
  end

  def delete(conn, %{"di_id" => di_id, "num" => num, "plid" => plid}) do
    {di_id, num, plid} = _params_to_integers(di_id, num, plid)

    case Registrar.instance_registry(di_id) do
      {:ok, instance_registry} -> LevelRegistry.remove(instance_registry, num, plid)
      _ -> nil
    end

    conn
    |> put_flash(:info, "Removing level instance process with for dungein instance #{di_id} level number `#{num}`, owner id `#{plid}`")
    |> redirect(to: Routes.manage_dungeon_process_path(conn, :show, di_id))
  end

  defp _params_to_integers(di_id, num, plid) do
    {
      String.to_integer(di_id),
      String.to_integer(num),
      if(plid == "none", do: nil, else: String.to_integer(plid))
    }
  end
end

defmodule DungeonCrawlWeb.ManageDungeonInstanceController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess

  def index(conn, _params) do
    instances = InstanceRegistry.list(DungeonInstanceRegistry)
                |> Enum.map(fn({instance_id, instance}) ->
                              state = InstanceProcess.get_state(instance)
                                      |> Map.take([:instance_id, :map_set_instance_id, :number, :player_locations])
                              {state, DungeonInstances.get_map(instance_id)}
                            end)
    render(conn, "index.html", instances: instances)
  end

  def show(conn, %{"id" => id}) do
    case InstanceRegistry.lookup(DungeonInstanceRegistry, String.to_integer(id)) do
      {:ok, instance_process} ->
        instance_state = InstanceProcess.get_state(instance_process)
        instance = Repo.preload(DungeonInstances.get_map(String.to_integer(id)), [dungeon: :map_set])
        render(conn, "show.html", instance_state: instance_state, instance: instance)
      _ ->
        conn
        |> put_flash(:info, "Instance not found: `#{id}`")
        |> redirect(to: Routes.manage_dungeon_instance_path(conn, :index))
    end
  end

  def delete(conn, %{"id" => id}) do
    InstanceRegistry.remove(DungeonInstanceRegistry, String.to_integer(id))

    conn
    |> put_flash(:info, "Removing instance process with id `#{id}`")
    |> redirect(to: Routes.manage_dungeon_instance_path(conn, :index))
  end
end

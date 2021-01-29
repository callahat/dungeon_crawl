defmodule DungeonCrawlWeb.ManageMapSetInstanceController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.MapSetRegistry
  alias DungeonCrawl.DungeonProcesses.MapSetProcess

  def index(conn, _params) do
    map_sets = MapSetRegistry.list(MapSetInstanceRegistry)
               |> Enum.map(fn({msi_id, map_set}) ->
                             state = MapSetProcess.get_state(map_set)
                                     |> Map.take([:map_set_instance])
                             {state, DungeonInstances.get_map_set(msi_id)}
                           end)
    render(conn, "index.html", map_sets: map_sets)
  end

  def show(conn, %{"id" => id}) do
    case MapSetRegistry.lookup(MapSetInstanceRegistry, String.to_integer(id)) do
      {:ok, map_set_process} ->
        map_set_instance = DungeonInstances.get_map_set(String.to_integer(id))
        map_set_state = MapSetProcess.get_state(map_set_process)

        instances = InstanceRegistry.list(map_set_state.instance_registry)
                    |> Enum.map(fn({instance_id, instance}) ->
                                  state = InstanceProcess.get_state(instance)
                                          |> Map.take([:instance_id, :map_set_instance_id, :number, :player_locations])
                                  {state, DungeonInstances.get_map(instance_id)}
                                end)

        render(conn, "show.html", msi_id: id, map_set_instance: map_set_instance, map_set_state: map_set_state, instances: instances)
      _ ->
        conn
        |> put_flash(:info, "Instance not found: `#{id}`")
        |> redirect(to: Routes.manage_map_set_instance_path(conn, :index))
    end
  end

  def delete(conn, %{"id" => id}) do
    MapSetRegistry.remove(MapSetInstanceRegistry, String.to_integer(id))

    conn
    |> put_flash(:info, "Removing instance process with id `#{id}`")
    |> redirect(to: Routes.manage_map_set_instance_path(conn, :index))
  end
end

defmodule DungeonCrawlWeb.ManageDungeonProcessController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.LevelRegistry
  alias DungeonCrawl.DungeonProcesses.LevelProcess
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry
  alias DungeonCrawl.DungeonProcesses.DungeonProcess

  def index(conn, _params) do
    dungeons = DungeonRegistry.list(DungeonInstanceRegistry)
               |> Enum.map(fn({di_id, dungeon}) ->
                             state = DungeonProcess.get_state(dungeon)
                                     |> Map.take([:dungeon_instance])
                             {state, DungeonInstances.get_dungeon(di_id)}
                           end)
    render(conn, "index.html", dungeons: dungeons)
  end

  def show(conn, %{"id" => id}) do
    case DungeonRegistry.lookup(DungeonInstanceRegistry, String.to_integer(id)) do
      {:ok, dungeon_process} ->
        dungeon_instance = DungeonInstances.get_dungeon(String.to_integer(id))
        dungeon_state = DungeonProcess.get_state(dungeon_process)

        # TODO: this looks wrong
        instances = LevelRegistry.list(dungeon_state.instance_registry)
                    |> Enum.flat_map(fn {_number, owners} -> Enum.map(owners, fn {_owner, pair} -> pair end) end)
                    |> Enum.map(fn({instance_id, instance}) ->
                                  state = LevelProcess.get_state(instance)
                                          |> Map.take([:instance_id, :dungeon_instance_id, :number, :player_locations, :player_location_id])
                                  {state, DungeonInstances.get_level(instance_id), instance}
                                end)

        render(conn, "show.html", di_id: id, dungeon_instance: dungeon_instance, dungeon_state: dungeon_state, instances: instances)
      _ ->
        conn
        |> put_flash(:info, "Dungeon instance process not found: `#{id}`")
        |> redirect(to: Routes.manage_dungeon_process_path(conn, :index))
    end
  end

  def delete(conn, %{"id" => id}) do
    DungeonRegistry.remove(DungeonInstanceRegistry, String.to_integer(id))

    conn
    |> put_flash(:info, "Removing dungeon instance process with id `#{id}`")
    |> redirect(to: Routes.manage_dungeon_process_path(conn, :index))
  end
end

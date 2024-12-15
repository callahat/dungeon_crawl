defmodule DungeonCrawlWeb.Admin.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Games

  def index(conn, %{"show_deleted" => "true"}) do
    dungeons = Dungeons.list_dungeons(:soft_deleted)
               |> Enum.map(fn(dungeon) -> Repo.preload(dungeon, [:levels, :locations, :dungeon_instances, :saves]) end)
    render(conn, "index_deleted.html", dungeons: dungeons)
  end

  def index(conn, _params) do
    dungeons = Dungeons.list_dungeons_with_player_count()
               |> Enum.map(fn(%{dungeon: dungeon}) -> Repo.preload(dungeon, [:levels, :locations, :dungeon_instances, :saves]) end)
    render(conn, "index.html", dungeons: dungeons)
  end

  def show(conn, %{"id" => id, "instance_id" => instance_id} = params) do
    dungeon = Dungeons.get_dungeon!(id)
              |> Repo.preload([:locations, :saves, [levels: :tiles]])
    dungeon_instance = DungeonInstances.get_dungeon(instance_id)
                       |> Repo.preload([:levels, [saves: :level_instance], level_headers: [:level, :levels]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"
    level = case Integer.parse(params["level"] || "") do
              {num, _} -> num
              _ -> nil
            end
    plid = case Integer.parse(params["plid"] || "") do
             {num, _} -> num
             _ -> nil
           end

    render(conn, "show.html", dungeon: dungeon, dungeon_instance: dungeon_instance, owner_name: owner_name, level: level, plid: plid)
  end

  def show(conn, %{"id" => id}) do
    dungeon = Dungeons.get_dungeon!(id)
              |> Repo.preload([:locations, :saves, [levels: :tiles]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    render(conn, "show.html", dungeon: dungeon, dungeon_instance: nil, owner_name: owner_name, level: nil)
  end

  def delete(conn, %{"id" => id, "instance_id" => instance_id, "save_id" => save_id}) do
    dungeon = Dungeons.get_dungeon!(id)
    save = Games.get_save(save_id)

    Games.delete_save(save)

    conn
    |> put_flash(:info, "Save deleted successfully.")
    |> redirect(to: Routes.admin_dungeon_path(conn, :show, dungeon, instance_id: instance_id))
  end

  def delete(conn, %{"id" => id, "instance_id" => instance_id}) do
    dungeon = Dungeons.get_dungeon!(id)
    dungeon_instance = DungeonInstances.get_dungeon(instance_id)

    DungeonInstances.delete_dungeon(dungeon_instance)

    conn
    |> put_flash(:info, "Dungeon Instance deleted successfully.")
    |> redirect(to: Routes.admin_dungeon_path(conn, :show, dungeon))
  end

  def delete(conn, %{"id" => id, "hard_delete" => "true"}) do
    dungeon = Dungeons.get_dungeon!(id)

    Dungeons.hard_delete_dungeon!(dungeon)

    conn
    |> put_flash(:info, "Dungeon #{dungeon.name} v#{dungeon.version} hard deleted successfully.")
    |> redirect(to: Routes.admin_dungeon_path(conn, :index, %{show_deleted: "true"}))
  end

  def delete(conn, %{"id" => id}) do
    dungeon = Dungeons.get_dungeon!(id)

    Dungeons.delete_dungeon!(dungeon)

    conn
    |> put_flash(:info, "Dungeon #{dungeon.name} v#{dungeon.version} deleted successfully.")
    |> redirect(to: Routes.admin_dungeon_path(conn, :index))
  end
end

defmodule DungeonCrawlWeb.ManageDungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances

  def index(conn, _params) do
    dungeons = Dungeon.list_dungeons_with_player_count()
    render(conn, "index.html", dungeons: dungeons)
  end

  def show(conn, %{"id" => id, "instance_id" => instance_id}) do
    dungeon = Dungeon.get_map!(id) |> Repo.preload([:user, :dungeon_map_tiles, map_instances: [:locations]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"
    instance = DungeonInstances.get_map(instance_id)

    render(conn, "show.html", dungeon: dungeon, instance: instance, owner_name: owner_name)
  end

  def show(conn, %{"id" => id}) do
    dungeon = Dungeon.get_map!(id) |> Repo.preload([:dungeon_map_tiles, map_instances: [:locations]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    render(conn, "show.html", dungeon: dungeon, instance: nil, owner_name: owner_name)
  end

  def delete(conn, %{"id" => id}) do
    dungeon = Dungeon.get_map!(id)

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: Routes.manage_dungeon_path(conn, :index))
  end
end

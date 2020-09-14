defmodule DungeonCrawlWeb.ManageDungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances

  def index(conn, %{"show_deleted" => "true"}) do
    map_sets = Dungeon.list_map_sets(:soft_deleted)
               |> Enum.map(fn(map_set) -> Repo.preload(map_set, [:dungeons]) end)
    render(conn, "index_deleted.html", map_sets: map_sets)
  end

  def index(conn, _params) do
    map_sets = Dungeon.list_map_sets_with_player_count()
               |> Enum.map(fn(%{map_set: map_set}) -> Repo.preload(map_set, [:dungeons, :locations, :map_set_instances]) end)
    render(conn, "index.html", map_sets: map_sets)
  end

  def show(conn, %{"id" => id, "instance_id" => instance_id}) do
    map_set = Dungeon.get_map_set!(id)
              |> Repo.preload([:locations, [dungeons: :dungeon_map_tiles]])
    map_set_instance = DungeonInstances.get_map_set(instance_id)
                       |> Repo.preload([:maps])
    top_level = Enum.at(map_set.dungeons, 0)
    top_level = if top_level, do: top_level.number, else: nil
    owner_name = if map_set.user_id, do: Repo.preload(map_set, :user).user.name, else: "<None>"

    render(conn, "show.html", map_set: map_set, map_set_instance: map_set_instance, owner_name: owner_name, top_level: top_level)
  end

  def show(conn, %{"id" => id}) do
    map_set = Dungeon.get_map_set!(id)
              |> Repo.preload([:locations, [dungeons: :dungeon_map_tiles]])
    top_level = Enum.at(map_set.dungeons, 0)
    top_level = if top_level, do: top_level.number, else: nil
    owner_name = if map_set.user_id, do: Repo.preload(map_set, :user).user.name, else: "<None>"

    render(conn, "show.html", map_set: map_set, map_set_instance: nil, owner_name: owner_name, top_level: top_level)
  end

  def delete(conn, %{"id" => id, "instance_id" => instance_id}) do
    map_set = Dungeon.get_map_set!(id)
    map_set_instance = DungeonInstances.get_map_set(instance_id)

    DungeonInstances.delete_map_set(map_set_instance)

    conn
    |> put_flash(:info, "Dungeon Instance deleted successfully.")
    |> redirect(to: Routes.manage_dungeon_path(conn, :show, map_set))
  end

  def delete(conn, %{"id" => id, "hard_delete" => "true"}) do
    map_set = Dungeon.get_map_set!(id)

    Dungeon.hard_delete_map_set!(map_set)

    conn
    |> put_flash(:info, "Dungeon #{map_set.name} v#{map_set.version} hard deleted successfully.")
    |> redirect(to: Routes.manage_dungeon_path(conn, :index, %{show_deleted: "true"}))
  end

  def delete(conn, %{"id" => id}) do
    map_set = Dungeon.get_map_set!(id)

    Dungeon.delete_map_set!(map_set)

    conn
    |> put_flash(:info, "Dungeon #{map_set.name} v#{map_set.version} deleted successfully.")
    |> redirect(to: Routes.manage_dungeon_path(conn, :index))
  end
end

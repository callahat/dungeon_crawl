defmodule DungeonCrawlWeb.ManageDungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.DungeonGenerator

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || DungeonGenerator

  def index(conn, _params) do
    dungeons = Dungeon.list_dungeons_with_player_count()
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.change_map(%Map{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"map" => dungeon_params}) do
    case Dungeon.generate_map(@dungeon_generator, dungeon_params) do
      {:ok, %{dungeon: dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: manage_dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, changeset, _others} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id, "instance_id" => instance_id}) do
    dungeon = Dungeon.get_map!(id) |> Repo.preload([:user, map_instances: [:locations]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"
    instance = DungeonInstances.get_map!(instance_id) |> Repo.preload([dungeon_map_tiles: [:tile_template]])

    render(conn, "show.html", dungeon: dungeon, instance: instance, owner_name: owner_name)
  end

  def show(conn, %{"id" => id}) do
    dungeon = Dungeon.get_map!(id) |> Repo.preload([map_instances: [:locations], dungeon_map_tiles: [:tile_template]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    render(conn, "show.html", dungeon: dungeon, instance: nil, owner_name: owner_name)
  end

  def delete(conn, %{"id" => id}) do
    dungeon = Dungeon.get_map!(id)

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: manage_dungeon_path(conn, :index))
  end
end
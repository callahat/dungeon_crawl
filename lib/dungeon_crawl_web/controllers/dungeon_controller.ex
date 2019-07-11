defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.DungeonGenerator
  alias DungeonCrawl.EmptyGenerator

  plug :assign_dungeon when action in [:show, :edit, :update, :delete, :activate, :new_version]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || DungeonGenerator

  def index(conn, _params) do
    dungeons = Dungeon.list_dungeons(conn.assigns.current_user)
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.change_map(%Map{})
    generators = ["Rooms", "Empty Map"]
    render(conn, "new.html", changeset: changeset, generators: generators)
  end

  def create(conn, %{"map" => dungeon_params}) do
    generator = case dungeon_params["generator"] do
                  "Rooms" -> DungeonGenerator
                  _       -> EmptyGenerator
                end

    case Dungeon.generate_map(generator, Elixir.Map.put(dungeon_params, "user_id", conn.assigns.current_user.id), true) do
      {:ok, %{dungeon: dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, changeset, _others} ->
        generators = ["Rooms", "Empty Map"]
        render(conn, "new.html", changeset: changeset, generators: generators)
    end
  end

  def show(conn, %{"id" => id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id) |> Repo.preload([map_instances: [:locations], dungeon_map_tiles: [:tile_template]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    render(conn, "show.html", dungeon: dungeon, owner_name: owner_name)
  end

  def edit(conn, %{"id" => id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id) |> Repo.preload([dungeon_map_tiles: [:tile_template]])
    changeset = Dungeon.change_map(dungeon)
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).name, else: "<None>"

    render(conn, "edit.html", dungeon: dungeon, changeset: changeset)
  end

  def update(conn, %{"id" => id, "map" => dungeon_params}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    case Dungeon.update_map(dungeon, dungeon_params) do
      {:ok, dungeon} ->
        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        render(conn, "edit.html", dungeon: dungeon, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: dungeon_path(conn, :index))
  end

  def activate(conn, %{"id" => id}) do
    dungeon = conn.assigns.dungeon
    if dungeon.previous_version_id, do: Dungeon.delete_map!(Dungeon.get_map!(dungeon.previous_version_id))

    case Dungeon.update_map(dungeon, %{active: true}) do
      {:ok, dungeon} ->
        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        render(conn, "edit.html", dungeon: dungeon, changeset: changeset)
    end
  end

  def new_version(conn, %{"id" => id}) do
    dungeon = conn.assigns.dungeon

    case Dungeon.create_new_map_version(dungeon) do
      {:ok, %{dungeon: new_dungeon_version}} ->
        conn
        |> put_flash(:info, "New dungeon version created successfully.")
        |> redirect(to: dungeon_path(conn, :show, new_dungeon_version))
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: dungeon_path(conn, :show, dungeon))
    end
  end

  defp assign_dungeon(conn, _opts) do
    dungeon =  Dungeon.get_map!(conn.params["id"] || conn.params["dungeon_id"])

    if dungeon.user_id == conn.assigns.current_user.id do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:dungeon, Repo.preload(dungeon, [dungeon_map_tiles: :tile_template]))
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: dungeon_path(conn, :index))
      |> halt()
    end
  end
end

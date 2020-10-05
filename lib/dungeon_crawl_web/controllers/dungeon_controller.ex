defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.MapSet
  alias DungeonCrawl.Player

  import DungeonCrawlWeb.Crawler, only: [join_and_broadcast: 2, leave_and_broadcast: 1]

  plug :authenticate_user
  plug :validate_edit_dungeon_available
  plug :assign_player_location when action in [:show, :index, :test_crawl]
  plug :assign_map_set when action in [:show, :edit, :update, :delete, :activate, :new_version, :test_crawl]
  plug :validate_updateable when action in [:edit, :update]

  def index(conn, _params) do
    map_sets = Dungeon.list_map_sets(conn.assigns.current_user)
               |> Repo.preload(:dungeons)
    render(conn, "index.html", map_sets: map_sets)
  end

  def new(conn, _params) do
    changeset = Dungeon.change_map_set(%MapSet{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"map_set" => dungeon_params}) do
    atomized_dungeon_params = Enum.reduce(dungeon_params, %{}, fn
        {key, value}, acc when is_atom(key) -> Elixir.Map.put(acc, key, value)
        {key, value}, acc when is_binary(key) -> Elixir.Map.put(acc, String.to_existing_atom(key), value)
       end)

    case Dungeon.create_map_set(Elixir.Map.put(atomized_dungeon_params, :user_id, conn.assigns.current_user.id)) do
      {:ok, map_set} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")

        |> redirect(to: Routes.dungeon_path(conn, :show, map_set))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => _id}) do
    map_set = conn.assigns.map_set
              |> Repo.preload([dungeons: [dungeon_map_tiles: :tile_template]])
    owner_name = if map_set.user_id, do: Repo.preload(map_set, :user).user.name, else: "<None>"

    top_level = Enum.at(map_set.dungeons, 0)
    top_level = if top_level, do: top_level.number, else: nil

    render(conn, "show.html", map_set: map_set, owner_name: owner_name, top_level: top_level)
  end

  def edit(conn, %{"id" => _id}) do
    map_set = conn.assigns.map_set

    changeset = Dungeon.change_map_set(map_set)

    render(conn, "edit.html", map_set: map_set, changeset: changeset)
  end

  def update(conn, %{"id" => _id, "map_set" => map_set_params}) do
    map_set = conn.assigns.map_set

    case Dungeon.update_map_set(map_set, map_set_params) do
      {:ok, map_set} ->
        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, map_set))

      {:error, changeset} ->
        render(conn, "edit.html", map_set: map_set, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => _id}) do
    map_set = conn.assigns.map_set #Dungeon.get_map!(id)

    Dungeon.delete_map_set!(map_set)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: Routes.dungeon_path(conn, :index))
  end

  def activate(conn, %{"id" => _id}) do
    map_set = conn.assigns.map_set

    case Dungeon.activate_map_set(map_set) do
      {:ok, active_map_set} ->
        conn
        |> put_flash(:info, "Dungeon activated.")
        |> redirect(to: Routes.dungeon_path(conn, :show, active_map_set))

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.dungeon_path(conn, :show, map_set))
    end
  end

  def new_version(conn, %{"id" => _id}) do
    map_set = conn.assigns.map_set

    case Dungeon.create_new_map_set_version(map_set) do
      {:ok, new_map_set_version} ->
        conn
        |> put_flash(:info, "New dungeon version created successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, new_map_set_version))
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.dungeon_path(conn, :show, map_set))
      {:error, :new_maps, _, _} ->
        conn
        |> put_flash(:error, "Cannot create new version; dimensions restricted?")
        |> redirect(to: Routes.dungeon_path(conn, :show, map_set))
    end
  end

  def test_crawl(conn, %{"id" => _id}) do
    if Enum.count(conn.assigns.map_set.dungeons) < 1 do
      conn
      |> put_flash(:error, "Add a dungeon level first")
      |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.map_set))
      |> halt()
    else
     if conn.assigns.player_location, do: leave_and_broadcast(conn.assigns.player_location)

      join_and_broadcast(conn.assigns.map_set, conn.assigns[:user_id_hash])

      conn
      |> redirect(to: Routes.crawler_path(conn, :show))
    end
  end

  defp validate_edit_dungeon_available(conn, _opts) do
    if conn.assigns.current_user.is_admin or Admin.get_setting().non_admin_dungeons_enabled do
      conn
    else
      conn
      |> put_flash(:error, "Edit dungeons is disabled")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp assign_player_location(conn, _opts) do
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(map_tile: [:dungeon, dungeon: [dungeon_map_tiles: :tile_template]])
    conn
    |> assign(:player_location, player_location)
  end

  defp assign_map_set(conn, _opts) do
    map_set =  Dungeon.get_map_set!(conn.params["id"] || conn.params["map_set_id"])

    if map_set.user_id == conn.assigns.current_user.id do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:map_set, Repo.preload(map_set, :dungeons))
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp validate_updateable(conn, _opts) do
    if !conn.assigns.map_set.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit an active dungeon")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end
end

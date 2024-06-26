defmodule DungeonCrawlWeb.Editor.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Games
  alias DungeonCrawl.Player
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.DockWorker
  alias DungeonCrawl.Shipping.DungeonImports

  import DungeonCrawlWeb.Crawler, only: [join_and_broadcast: 4, leave_and_broadcast: 1]

  plug :authenticate_user
  plug :validate_edit_dungeon_available
  plug :assign_player_location when action in [:show, :index, :test_crawl]
  plug :assign_dungeon when action in [:show, :edit, :update, :delete, :activate, :new_version, :test_crawl, :dungeon_export]
  plug :assign_dungeon_import when action in [:dungeon_import_show, :dungeon_import_update]
  plug :assign_dungeon_export when action in [:download_dungeon_export]
  plug :validate_updateable when action in [:edit, :update]
  plug :validate_import_updateable when action in [:dungeon_import_update]

  def index(conn, _params) do
    dungeons = Dungeons.list_dungeons(conn.assigns.current_user)
               |> Repo.preload(:levels)
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeons.change_dungeon(%Dungeon{})
    render(conn, "new.html", changeset: changeset, max_dimensions: _max_dimensions())
  end

  def create(conn, %{"dungeon" => dungeon_params}) do
    atomized_dungeon_params = Enum.reduce(dungeon_params, %{}, fn
        {key, value}, acc when is_atom(key) -> Elixir.Map.put(acc, key, value)
        {key, value}, acc when is_binary(key) -> Elixir.Map.put(acc, String.to_existing_atom(key), value)
       end)

    case Dungeons.create_dungeon(Elixir.Map.put(atomized_dungeon_params, :user_id, conn.assigns.current_user.id)) do
      {:ok, dungeon} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset, max_dimensions: _max_dimensions())
    end
  end

  def show(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon
              |> Repo.preload([levels: [tiles: :tile_template]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    top_level = Enum.at(dungeon.levels, 0)
    top_level = if top_level, do: top_level.number, else: nil

    title_level = Dungeons.get_title_level(dungeon)

    render(conn, "show.html", dungeon: dungeon, owner_name: owner_name, top_level: top_level, title_level: title_level)
  end

  def edit(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    changeset = Dungeons.change_dungeon(dungeon)

    render(conn, "edit.html", dungeon: dungeon, changeset: changeset, max_dimensions: _max_dimensions())
  end

  def update(conn, %{"id" => _id, "dungeon" => dungeon_params}) do
    dungeon = conn.assigns.dungeon

    case Dungeons.update_dungeon(dungeon, dungeon_params) do
      {:ok, dungeon} ->
        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, dungeon))

      {:error, changeset} ->
        render(conn, "edit.html", dungeon: dungeon, changeset: changeset, max_dimensions: _max_dimensions())
    end
  end

  def dungeon_import(conn, _) do
    assign(conn, :user_id_hash, conn.assigns.current_user.user_id_hash)
    |> render("import.html")
  end

  def dungeon_import_show(conn, %{"id" => _id}) do
    dungeon_import = conn.assigns.dungeon_import
    asset_imports = DungeonImports.get_asset_imports(dungeon_import.id, :unresolved)

    assign(conn, :dungeon_import, dungeon_import)
    |> assign(:asset_imports, asset_imports)
    |> assign(:user, conn.assigns.current_user)
    |> render("import_show.html")
  end

  def dungeon_import_update(conn, %{"id" => _id, "action" => action}) do
    dungeon_import = conn.assigns.dungeon_import

    Enum.each(action, fn {asset_import_id, action} ->
      asset_import = DungeonImports.get_asset_import(dungeon_import.id, asset_import_id)
      if asset_import, do: DungeonImports.update_asset_import!(asset_import, %{action: action})
    end)

    DockWorker.import(dungeon_import)

    conn
    |> put_flash(:info, "Continuing import")
    |> _redirect_to_dungeon_import_list()
  end

  def dungeon_export(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    dungeon_export = Shipping.create_export!(%{
      dungeon_id: dungeon.id,
      user_id: conn.assigns.current_user.id
    })

    DockWorker.export(dungeon_export)

    conn
    |> _redirect_to_dungeon_export_list()

  rescue
    Ecto.InvalidChangesetError -> _redirect_to_dungeon_export_list(conn)
  end

  def dungeon_export_list(conn, _) do
    assign(conn, :user_id_hash, conn.assigns.current_user.user_id_hash)
    |> render("export.html")
  end

  defp _redirect_to_dungeon_export_list(conn) do
    redirect(conn, to: Routes.edit_dungeon_export_path(conn, :dungeon_export_list))
  end

  defp _redirect_to_dungeon_import_list(conn) do
    redirect(conn, to: Routes.edit_dungeon_import_path(conn, :dungeon_import))
  end

  def download_dungeon_export(conn, %{"id" => _id}) do
    export = conn.assigns.dungeon_export

    send_download(conn, {:binary, export.data}, filename: export.file_name)
  end

  def delete(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    Dungeons.delete_dungeon!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: Routes.edit_dungeon_path(conn, :index))
  end

  def activate(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    case Dungeons.activate_dungeon(dungeon) do
      {:ok, active_dungeon} ->
        if active_dungeon.previous_version_id, do: Games.convert_saves(active_dungeon)

        conn
        |> put_flash(:info, "Dungeon activated.")
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, active_dungeon))

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, dungeon))
    end
  end

  def new_version(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    case Dungeons.create_new_dungeon_version(dungeon) do
      {:ok, new_dungeon_version} ->
        conn
        |> put_flash(:info, "New dungeon version created successfully.")
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, new_dungeon_version))
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, dungeon))
      {:error, :new_levels, _, _} ->
        conn
        |> put_flash(:error, "Cannot create new version; dimensions restricted?")
        |> redirect(to: Routes.edit_dungeon_path(conn, :show, dungeon))
    end
  end

  def test_crawl(conn, %{"id" => _id}) do
    if Enum.count(conn.assigns.dungeon.levels) < 1 do
      conn
      |> put_flash(:error, "Add a level first")
      |> redirect(to: Routes.edit_dungeon_path(conn, :show, conn.assigns.dungeon))
      |> halt()
    else
     if conn.assigns.player_location, do: leave_and_broadcast(conn.assigns.player_location)

      join_and_broadcast(conn.assigns.dungeon, conn.assigns[:user_id_hash], %{}, true)

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
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp assign_player_location(conn, _opts) do
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(tile: [level: :tiles])
    conn
    |> assign(:player_location, player_location)
  end

  defp assign_dungeon(conn, _opts) do
    dungeon =  Dungeons.get_dungeon!(conn.params["id"] || conn.params["dungeon_id"])

    cond do
      dungeon.user_id != conn.assigns.current_user.id && !conn.assigns.current_user.is_admin ->
        conn
        |> put_flash(:error, "You do not have access to that")
        |> redirect(to: Routes.edit_dungeon_path(conn, :index))
        |> halt()

      dungeon.importing ->
        conn
        |> put_flash(:error, "Import still in progress, try again later.")
        |> redirect(to: Routes.edit_dungeon_path(conn, :index))
        |> halt()

      true ->
        conn
        |> assign(:dungeon, Repo.preload(dungeon, :levels))
    end
  end

  defp assign_dungeon_import(conn, _opts) do
    import =  Shipping.get_import!(conn.params["id"])

    if import.user_id == conn.assigns.current_user.id || conn.assigns.current_user.is_admin do
      conn
      |> assign(:dungeon_import, import)
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.edit_dungeon_import_path(conn, :dungeon_import))
      |> halt()
    end
  end

  defp assign_dungeon_export(conn, _opts) do
    export =  Shipping.get_export!(conn.params["id"])

    if export.user_id == conn.assigns.current_user.id || conn.assigns.current_user.is_admin do
      conn
      |> assign(:dungeon_export, export)
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.edit_dungeon_export_path(conn, :dungeon_export_list))
      |> halt()
    end
  end

  defp validate_updateable(conn, _opts) do
    if !conn.assigns.dungeon.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit an active dungeon")
      |> redirect(to: Routes.edit_dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp validate_import_updateable(conn, _opts) do
    if conn.assigns.dungeon_import.status == :waiting do
      conn
    else
      conn
      |> put_flash(:error, "Cannot continue with that dungeon import")
      |> _redirect_to_dungeon_import_list()
      |> halt()
    end
  end

  defp _max_dimensions() do
    Elixir.Map.take(Admin.get_setting, [:max_height, :max_width])
  end
end

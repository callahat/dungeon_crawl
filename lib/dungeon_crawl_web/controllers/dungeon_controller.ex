defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias DungeonCrawl.MapGenerators.Empty
  alias DungeonCrawl.MapGenerators.Labrynth
  alias DungeonCrawl.Player

  import DungeonCrawlWeb.Crawler, only: [join_and_broadcast: 2, leave_and_broadcast: 1]

  plug :authenticate_user
  plug :assign_player_location when action in [:show, :index, :test_crawl]
  plug :assign_dungeon when action in [:show, :edit, :update, :delete, :activate, :new_version, :test_crawl]
  plug :validate_updateable when action in [:edit, :update]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || ConnectedRooms

  def index(conn, _params) do
    dungeons = Dungeon.list_dungeons(conn.assigns.current_user)
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.change_map(%Map{})
    generators = ["Rooms", "Labrynth", "Empty Map"]
    render(conn, "new.html", changeset: changeset, generators: generators)
  end

  def create(conn, %{"map" => dungeon_params}) do
    generator = case dungeon_params["generator"] do
                  "Rooms"    -> @dungeon_generator
                  "Labrynth" -> Labrynth
                  _          -> Empty
                end

    case Dungeon.generate_map(generator, Elixir.Map.put(dungeon_params, "user_id", conn.assigns.current_user.id), true) do
      {:ok, %{dungeon: dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, changeset, _others} ->
        generators = ["Rooms", "Labrynth", "Empty Map"]
        render(conn, "new.html", changeset: changeset, generators: generators)
    end
  end

  def show(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id) |> Repo.preload([map_instances: [:locations], dungeon_map_tiles: [:tile_template]])
    owner_name = if dungeon.user_id, do: Repo.preload(dungeon, :user).user.name, else: "<None>"

    render(conn, "show.html", dungeon: dungeon, owner_name: owner_name)
  end

  def edit(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id) |> Repo.preload([dungeon_map_tiles: [:tile_template]])
    tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
    historic_templates = Dungeon.list_historic_tile_templates(dungeon)

    changeset = Dungeon.change_map(dungeon)

    render(conn, "edit.html", dungeon: dungeon, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates)
  end

  def update(conn, %{"id" => _id, "map" => dungeon_params}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    case Dungeon.update_map(dungeon, dungeon_params) do
      {:ok, dungeon} ->
        _make_tile_updates(dungeon, dungeon_params["tile_changes"])

        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
        historic_templates = Dungeon.list_historic_tile_templates(dungeon)
        render(conn, "edit.html", dungeon: dungeon, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates)
    end
  end

  # todo: modify the tile template check to verify use can use the tile template id (ie, not soft deleted, protected, etc
  defp _make_tile_updates(dungeon, tile_updates) do
    case Poison.decode(tile_updates) do
      {:ok, tile_updates} ->
        # TODO: move this to a method in Dungeon
        tile_updates
        |> Enum.map(fn(tu) -> [Dungeon.get_map_tile(dungeon.id, tu["row"], tu["col"]),
                               TileTemplates.get_tile_template(tu["tile_template_id"]),
                               tu["color"],
                               tu["background_color"]
                              ] end)
        |> Enum.reject(fn([d,t,_,_]) -> is_nil(d) || is_nil(t) end)
        |> Enum.map(fn([dmt, tt, color, background_color]) ->
             Dungeon.update_map_tile!(dmt, %{tile_template_id: tt.id,
                                             character: tt.character,
                                             color: color || tt.color,
                                             background_color: background_color || tt.background_color,
                                             state: tt.state,
                                             script: tt.script
                                            })
           end)

      {:error, _, _} ->
        false # noop
    end
  end

  def delete(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: dungeon_path(conn, :index))
  end

  def activate(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    case Dungeon.activate_map(dungeon) do
      {:ok, active_dungeon} ->
        conn
        |> put_flash(:info, "Dungeon activated.")
        |> redirect(to: dungeon_path(conn, :show, active_dungeon))

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: dungeon_path(conn, :show, dungeon))
    end
  end

  def new_version(conn, %{"id" => _id}) do
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

  def test_crawl(conn, %{"id" => _id}) do
    if conn.assigns.player_location, do: leave_and_broadcast(conn.assigns.player_location)

    join_and_broadcast(conn.assigns.dungeon, conn.assigns[:user_id_hash])

    conn
    |> put_flash(:info, "Dungeon joined successfully.")
    |> redirect(to: crawler_path(conn, :show))
  end

  defp assign_player_location(conn, _opts) do
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(map_tile: [:dungeon, dungeon: [dungeon_map_tiles: :tile_template]])
    conn
    |> assign(:player_location, player_location)
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

  defp validate_updateable(conn, _opts) do
    if !conn.assigns.dungeon.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit an active dungeon")
      |> redirect(to: dungeon_path(conn, :index))
      |> halt()
    end
  end
end

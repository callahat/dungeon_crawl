defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias DungeonCrawl.MapGenerators.Empty
  alias DungeonCrawl.MapGenerators.Labrynth
  alias DungeonCrawl.Player

  import DungeonCrawlWeb.Crawler, only: [join_and_broadcast: 2, leave_and_broadcast: 1]

  plug :authenticate_user
  plug :validate_edit_dungeon_available
  plug :assign_player_location when action in [:show, :index, :test_crawl]
  plug :assign_dungeon when action in [:show, :edit, :update, :delete, :activate, :new_version, :test_crawl]
  plug :validate_updateable when action in [:edit, :update]
  plug :set_sidebar_present_md when action in [:edit, :update]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || ConnectedRooms

  def index(conn, _params) do
    dungeons = Dungeon.list_dungeons(conn.assigns.current_user)
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.change_map(%Map{})
    generators = ["Rooms", "Labrynth", "Empty Map"]
    render(conn, "new.html", changeset: changeset, generators: generators, max_dimensions: _max_dimensions())
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
        |> redirect(to: Routes.dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, changeset, _others} ->
        generators = ["Rooms", "Labrynth", "Empty Map"]
        render(conn, "new.html", changeset: changeset, generators: generators, max_dimensions: _max_dimensions())
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
    {low_z, high_z} = Dungeon.get_bounding_z_indexes(dungeon)

    render(conn, "edit.html", dungeon: dungeon, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates, low_z_index: low_z, high_z_index: high_z, max_dimensions: _max_dimensions())
  end

  def update(conn, %{"id" => _id, "map" => dungeon_params}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    case Dungeon.update_map(dungeon, dungeon_params) do
      {:ok, dungeon} ->
        _make_tile_updates(dungeon, dungeon_params["tile_changes"])
        _make_tile_additions(dungeon, dungeon_params["tile_additions"])
        _make_tile_deletions(dungeon, dungeon_params["tile_deletions"])

        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        {low_z, high_z} = Dungeon.get_bounding_z_indexes(dungeon)
        tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
        historic_templates = Dungeon.list_historic_tile_templates(dungeon)
        render(conn, "edit.html", dungeon: dungeon, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates, low_z_index: low_z, high_z_index: high_z, max_dimensions: _max_dimensions())
    end
  end

  # todo: modify the tile template check to verify use can use the tile template id (ie, not soft deleted, protected, etc
  defp _make_tile_updates(dungeon, tile_updates) do
    case Jason.decode(tile_updates) do
      {:ok, tile_updates} ->
        # TODO: move this to a method in Dungeon
        tile_updates
        |> Enum.map(fn(tu) -> [Dungeon.get_map_tile(dungeon.id, tu["row"], tu["col"], tu["z_index"]),
                               TileTemplates.get_tile_template(tu["tile_template_id"]),
                               tu
                              ] end)
        |> Enum.reject(fn([d,_,_]) -> is_nil(d) end)
        |> Enum.map(fn([dmt, tt, tu]) ->
             Dungeon.update_map_tile!(dmt, %{tile_template_id: tt.id,
                                             character: tu["character"] || tt.character,
                                             color: tu["color"] || tt.color,
                                             background_color: tu["background_color"] || tt.background_color,
                                             state: tu["state"] || tt.state,
                                             script: tu["script"] || tt.script,
                                             name: tu["name"] || tt.name
                                            })
           end)

      {:error, _, _} ->
        false # noop
    end
  end

  defp _make_tile_additions(dungeon, tile_additions) do
    case Jason.decode(tile_additions) do
      {:ok, tile_additions} ->
        # TODO: move this to a method in Dungeon
        tile_additions
        |> Enum.map(fn(ta) -> [TileTemplates.get_tile_template(ta["tile_template_id"]),
                               ta
                              ] end)
        |> Enum.reject(fn([tt,_]) -> is_nil(tt) end)
        |> Enum.map(fn([tt, ta]) ->
             Dungeon.create_map_tile!(%{dungeon_id: dungeon.id,
                                        row: ta["row"],
                                        col: ta["col"],
                                        z_index: ta["z_index"],
                                        tile_template_id: tt.id,
                                        character: ta["character"] || tt.character,
                                        color: ta["color"] || tt.color,
                                        background_color: ta["background_color"] || tt.background_color,
                                        state: ta["state"] || tt.state,
                                        script: ta["script"] || tt.script,
                                        name: ta["name"] || tt.name
                                      })
           end)

      {:error, _, _} ->
        false # noop
    end
  end

  defp _make_tile_deletions(dungeon, tile_deletions) do
    case Jason.decode(tile_deletions) do
      {:ok, tile_deletions} ->
        # TODO: move this to a method in Dungeon
        tile_deletions
        |> Enum.map(fn(t) -> [t["row"],
                              t["col"],
                              t["z_index"]
                             ] end)
        |> Enum.map(fn([row, col, z_index]) ->
             Dungeon.delete_map_tile(dungeon.id, row, col, z_index)
           end)

      {:error, _, _} ->
        false # noop
    end
  end

  def validate_map_tile(conn, %{"id" => id, "map_tile" => map_tile_params}) do
    map_tile_changeset = Dungeon.MapTile.changeset(%Dungeon.MapTile{}, Elixir.Map.put(map_tile_params, "dungeon_id", id))
                         |> TileTemplates.TileTemplate.validate_script(%{user_id: conn.assigns.current_user.id})

    render(conn, "map_tile_errors.json", map_tile_errors: map_tile_changeset.errors)
  end

  def delete(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: Routes.dungeon_path(conn, :index))
  end

  def activate(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    case Dungeon.activate_map(dungeon) do
      {:ok, active_dungeon} ->
        conn
        |> put_flash(:info, "Dungeon activated.")
        |> redirect(to: Routes.dungeon_path(conn, :show, active_dungeon))

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.dungeon_path(conn, :show, dungeon))
    end
  end

  def new_version(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    case Dungeon.create_new_map_version(dungeon) do
      {:ok, %{dungeon: new_dungeon_version}} ->
        conn
        |> put_flash(:info, "New dungeon version created successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, new_dungeon_version))
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, _, _} ->
        conn
        |> put_flash(:error, "Cannot create new version; dimensions restricted?")
        |> redirect(to: Routes.dungeon_path(conn, :show, dungeon))
    end
  end

  def test_crawl(conn, %{"id" => _id}) do
    if conn.assigns.player_location, do: leave_and_broadcast(conn.assigns.player_location)

    join_and_broadcast(conn.assigns.dungeon, conn.assigns[:user_id_hash])

    conn
    |> redirect(to: Routes.crawler_path(conn, :show))
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

  defp assign_dungeon(conn, _opts) do
    dungeon =  Dungeon.get_map!(conn.params["id"] || conn.params["dungeon_id"])

    if dungeon.user_id == conn.assigns.current_user.id do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:dungeon, Repo.preload(dungeon, [dungeon_map_tiles: :tile_template]))
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp validate_updateable(conn, _opts) do
    if !conn.assigns.dungeon.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit an active dungeon")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp set_sidebar_present_md(conn, _opts) do
    conn
    |> assign(:sidebar_present_md, true)
  end

  defp _max_dimensions() do
    Elixir.Map.take(Admin.get_setting, [:max_height, :max_width])
  end
end

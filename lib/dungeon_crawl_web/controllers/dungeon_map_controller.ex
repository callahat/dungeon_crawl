defmodule DungeonCrawlWeb.DungeonMapController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias DungeonCrawl.MapGenerators.Empty
  alias DungeonCrawl.MapGenerators.Labrynth

  plug :authenticate_user
  plug :validate_edit_dungeon_available
  plug :assign_map_set when action in [:new, :create, :edit, :update, :delete, :map_edge]
  plug :assign_dungeon when action in [:edit, :update, :delete]
  plug :validate_updateable when action in [:edit, :update]
  plug :set_sidebar_col when action in [:edit, :update]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || ConnectedRooms

  def new(conn, _params) do
    changeset = Dungeon.change_map(%Map{}, %{height: conn.assigns.map_set.default_map_height, width: conn.assigns.map_set.default_map_width})
    generators = ["Rooms", "Labrynth", "Empty Map"]
    render(conn, "new.html", map_set: conn.assigns.map_set, dungeon: nil, changeset: changeset, generators: generators, max_dimensions: _max_dimensions())
  end

  def create(conn, %{"map" => dungeon_params}) do
    generator = case dungeon_params["generator"] do
                  "Rooms"    -> @dungeon_generator
                  "Labrynth" -> Labrynth
                  _          -> Empty
                end
    map_set = conn.assigns.map_set

    fixed_attributes = %{"user_id" => conn.assigns.current_user.id, "map_set_id" => map_set.id, "number" => Dungeon.next_level_number(map_set)}

    case Dungeon.generate_map(generator, Elixir.Map.merge(dungeon_params, fixed_attributes)) do
      {:ok, %{dungeon: dungeon}} ->
        Dungeon.link_unlinked_maps(dungeon)

        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, map_set))
      {:error, :dungeon, changeset, _others} ->
        generators = ["Rooms", "Labrynth", "Empty Map"]
        render(conn, "new.html", changeset: changeset, generators: generators, map_set: conn.assigns.map_set, max_dimensions: _max_dimensions())
    end
  end

  def edit(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id) |> Repo.preload([dungeon_map_tiles: [:tile_template]])
    tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
    historic_templates = Dungeon.list_historic_tile_templates(dungeon)

    changeset = Dungeon.change_map(dungeon)
    {low_z, high_z} = Dungeon.get_bounding_z_indexes(dungeon)
    spawn_locations = Repo.preload(dungeon, :spawn_locations).spawn_locations
                      |> Enum.into(%{}, fn(sl) -> {"#{sl.row}_#{sl.col}", true} end)

    adjacent_map_edge_tiles = Dungeon.adjacent_map_edge_tiles(dungeon)

    render(conn, "edit.html", map_set: conn.assigns.map_set, dungeon: dungeon, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates, low_z_index: low_z, high_z_index: high_z, max_dimensions: _max_dimensions(), spawn_locations: spawn_locations, adjacent_map_edge_tiles: adjacent_map_edge_tiles)
  end

  def update(conn, %{"id" => _id, "map" => dungeon_params}) do
    dungeon = conn.assigns.dungeon #Dungeon.get_map!(id)

    case Dungeon.update_map(dungeon, dungeon_params) do
      {:ok, dungeon} ->
        Dungeon.link_unlinked_maps(dungeon)

        _make_tile_updates(dungeon, dungeon_params["tile_changes"] || "")
        _make_tile_additions(dungeon, dungeon_params["tile_additions"] || "")
        _make_tile_deletions(dungeon, dungeon_params["tile_deletions"] || "")

        case Jason.decode(dungeon_params["spawn_tiles"] || "") do
          {:ok, coords} ->
            Dungeon.set_spawn_locations(dungeon.id, Enum.map(coords || [], fn([r, c]) -> {r, c} end))
          _error ->
            nil
        end

        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.map_set))
      {:error, changeset} ->
        {low_z, high_z} = Dungeon.get_bounding_z_indexes(dungeon)
        tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
        historic_templates = Dungeon.list_historic_tile_templates(dungeon)
        spawn_locations = Repo.preload(dungeon, :spawn_locations).spawn_locations
                          |> Enum.into(%{}, fn(sl) -> {"#{sl.row}_#{sl.col}", true} end)
        adjacent_map_edge_tiles = Dungeon.adjacent_map_edge_tiles(dungeon)

        render(conn, "edit.html", map_set: conn.assigns.map_set, dungeon: dungeon, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates, low_z_index: low_z, high_z_index: high_z, map_set: conn.assigns.map_set, max_dimensions: _max_dimensions(), spawn_locations: spawn_locations, adjacent_map_edge_tiles: adjacent_map_edge_tiles)
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
                                             name: tu["name"] || tt.name,
                                             animate_random: tu["animate_random"],
                                             animate_period: tu["animate_period"],
                                             animate_characters: tu["animate_characters"],
                                             animate_colors: tu["animate_colors"],
                                             animate_background_colors: tu["animate_background_colors"]
                                            })
           end)

      _error ->
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
                                        name: ta["name"] || tt.name,
                                        animate_random: ta["animate_random"],
                                        animate_period: ta["animate_period"],
                                        animate_characters: ta["animate_characters"],
                                        animate_colors: ta["animate_colors"],
                                        animate_background_colors: ta["animate_background_colors"]
                                      })
           end)

      _error ->
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

      _error ->
        false # noop
    end
  end

  def validate_map_tile(conn, %{"dungeon_id" => map_set_id, "id" => id, "map_tile" => map_tile_params}) do
    map_tile_changeset = Dungeon.MapTile.changeset(%Dungeon.MapTile{}, Elixir.Map.merge(map_tile_params, %{"map_set_id" => map_set_id, "dungeon_id" => id}))
                         |> TileTemplates.TileTemplate.validate_script(conn.assigns.current_user.id)

    render(conn, "map_tile_errors.json", map_tile_errors: map_tile_changeset.errors)
  end

  def delete(conn, %{"id" => _id}) do
    dungeon = conn.assigns.dungeon

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon level deleted successfully.")
    |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.map_set))
  end

  def map_edge(conn, %{"dungeon_id" => _map_set_id, "edge" => edge, "level_number" => level_number}) do
    inverse_edge = case edge do
                     "north" -> "south"
                     "south" -> "north"
                     "east" -> "west"
                     "west" -> "east"
                   end

    adjacent_map_edge_tiles = Dungeon.map_edge_tiles(Dungeon.get_map(conn.assigns.map_set.id, level_number), inverse_edge)

    render(conn, "adjacent_map_edge.json", edge: edge, adjacent_map_edge_tiles: adjacent_map_edge_tiles)
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

  defp assign_map_set(conn, _opts) do
    map_set =  Dungeon.get_map_set!(conn.params["dungeon_id"])

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

  defp assign_dungeon(conn, _opts) do
    incoming_id = case Integer.parse(conn.params["id"]) do
                    {int, ""} -> int
                    str -> str
                  end
    dungeon = Enum.find(conn.assigns.map_set.dungeons, fn(dungeon) -> dungeon.id == incoming_id end)

    if dungeon do
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
    if !conn.assigns.map_set.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit an active dungeon")
      |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.map_set))
      |> halt()
    end
  end

  defp set_sidebar_col(conn, _opts) do
    conn
    |> assign(:sidebar_col, 3)
  end

  defp _max_dimensions() do
    Elixir.Map.take(Admin.get_setting, [:max_height, :max_width])
  end
end

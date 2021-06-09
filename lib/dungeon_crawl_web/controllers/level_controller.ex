defmodule DungeonCrawlWeb.LevelController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.{Level, Tile}
  alias DungeonCrawl.TileShortlists
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias DungeonCrawl.MapGenerators.Empty
  alias DungeonCrawl.MapGenerators.Labrynth

  plug :authenticate_user
  plug :validate_edit_dungeon_available
  plug :assign_dungeon when action in [:new, :create, :edit, :update, :delete, :level_edge]
  plug :assign_level when action in [:edit, :update, :delete]
  plug :assign_tile_shortlist when action in [:edit, :update]
  plug :validate_updateable when action in [:edit, :update]
  plug :set_sidebar_col when action in [:edit, :update]

  @level_generator Application.get_env(:dungeon_crawl, :generator) || ConnectedRooms

  def new(conn, _params) do
    changeset = Dungeons.change_level(%Level{}, %{height: conn.assigns.dungeon.default_map_height, width: conn.assigns.dungeon.default_map_width})
    generators = ["Rooms", "Labrynth", "Empty Map"]
    render(conn, "new.html", dungeon: conn.assigns.dungeon, level: nil, changeset: changeset, generators: generators, max_dimensions: _max_dimensions())
  end

  def create(conn, %{"level" => level_params}) do
    generator = case level_params["generator"] do
                  "Rooms"    -> @level_generator
                  "Labrynth" -> Labrynth
                  _          -> Empty
                end
    dungeon = conn.assigns.dungeon

    fixed_attributes = %{"user_id" => conn.assigns.current_user.id, "dungeon_id" => dungeon.id, "number" => Dungeons.next_level_number(dungeon)}

    case Dungeons.generate_level(generator, Elixir.Map.merge(level_params, fixed_attributes)) do
      {:ok, %{level: level}} ->
        Dungeons.link_unlinked_levels(level)

        conn
        |> put_flash(:info, "Level created successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, dungeon))
      {:error, :level, changeset, _others} ->
        generators = ["Rooms", "Labrynth", "Empty Map"]
        render(conn, "new.html", changeset: changeset, generators: generators, dungeon: conn.assigns.dungeon, max_dimensions: _max_dimensions())
    end
  end

  def edit(conn, %{"id" => _id}) do
    level = conn.assigns.level
    tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
    historic_templates = Dungeons.list_historic_tile_templates(level)

    changeset = Dungeons.change_level(level)
    {low_z, high_z} = Dungeons.get_bounding_z_indexes(level)
    spawn_locations = Repo.preload(level, :spawn_locations).spawn_locations
                      |> Enum.into(%{}, fn(sl) -> {"#{sl.row}_#{sl.col}", true} end)

    adjacent_level_edge_tiles = Dungeons.adjacent_level_edge_tiles(level)

    render(conn, "edit.html", dungeon: conn.assigns.dungeon, level: level, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates, low_z_index: low_z, high_z_index: high_z, max_dimensions: _max_dimensions(), spawn_locations: spawn_locations, adjacent_level_edge_tiles: adjacent_level_edge_tiles, tile_shortlist: conn.assigns.tile_shortlist)
  end

  def update(conn, %{"id" => _id, "level" => level_params}) do
    level = conn.assigns.level

    case Dungeons.update_level(level, level_params) do
      {:ok, level} ->
        Dungeons.link_unlinked_levels(level)

        _make_tile_updates(level, level_params["tile_changes"] || "")
        _make_tile_additions(level, level_params["tile_additions"] || "")
        _make_tile_deletions(level, level_params["tile_deletions"] || "")

        case Jason.decode(level_params["spawn_tiles"] || "") do
          {:ok, coords} ->
            Dungeons.set_spawn_locations(level.id, Enum.map(coords || [], fn([r, c]) -> {r, c} end))
          _error ->
            nil
        end

        conn
        |> put_flash(:info, "Level updated successfully.")
        |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.dungeon))
      {:error, changeset} ->
        {low_z, high_z} = Dungeons.get_bounding_z_indexes(level)
        tile_templates = TileTemplates.list_placeable_tile_templates(conn.assigns.current_user)
        historic_templates = Dungeons.list_historic_tile_templates(level)
        spawn_locations = Repo.preload(level, :spawn_locations).spawn_locations
                          |> Enum.into(%{}, fn(sl) -> {"#{sl.row}_#{sl.col}", true} end)
        adjacent_level_edge_tiles = Dungeons.adjacent_level_edge_tiles(level)

        render(conn, "edit.html", dungeon: conn.assigns.dungeon, level: level, changeset: changeset, tile_templates: tile_templates, historic_templates: historic_templates, low_z_index: low_z, high_z_index: high_z, dungeon: conn.assigns.dungeon, max_dimensions: _max_dimensions(), spawn_locations: spawn_locations, adjacent_level_edge_tiles: adjacent_level_edge_tiles, tile_shortlist: conn.assigns.tile_shortlist)
    end
  end

  # todo: modify the tile template check to verify use can use the tile template id (ie, not soft deleted, protected, etc
  defp _make_tile_updates(level, tile_updates) do
    case Jason.decode(tile_updates) do
      {:ok, tile_updates} ->
        # TODO: move this to a method in Dungeon
        tile_updates
        |> Enum.map(fn(tu) -> [Dungeons.get_tile(level.id, tu["row"], tu["col"], tu["z_index"]),
                               TileTemplates.get_tile_template(tu["tile_template_id"]),
                               tu
                              ] end)
        |> Enum.reject(fn([d,_,_]) -> is_nil(d) end)
        |> Enum.map(fn([t, tt, tu]) ->
             Dungeons.update_tile!(t, %{tile_template_id: tt && tt.id,
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

  defp _make_tile_additions(level, tile_additions) do
    case Jason.decode(tile_additions) do
      {:ok, tile_additions} ->
        # TODO: move this to a method in Dungeon
        tile_additions
        |> Enum.map(fn(ta) -> [TileTemplates.get_tile_template(ta["tile_template_id"]) || %TileTemplate{},
                               ta
                              ] end)
        |> Enum.map(fn([tt, ta]) ->
             Dungeons.create_tile!(%{level_id: level.id,
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

  defp _make_tile_deletions(level, tile_deletions) do
    case Jason.decode(tile_deletions) do
      {:ok, tile_deletions} ->
        # TODO: move this to a method in Dungeon
        tile_deletions
        |> Enum.map(fn(t) -> [t["row"],
                              t["col"],
                              t["z_index"]
                             ] end)
        |> Enum.map(fn([row, col, z_index]) ->
             Dungeons.delete_tile(level.id, row, col, z_index)
           end)

      _error ->
        false # noop
    end
  end

  def validate_tile(conn, %{"dungeon_id" => dungeon_id, "id" => id, "tile" => tile_params}) do
    tile_changeset = Tile.changeset(%Tile{}, Elixir.Map.merge(tile_params, %{"dungeon_id" => dungeon_id, "level_id" => id}))
                     |> TileTemplates.TileTemplate.validate_script(conn.assigns.current_user.id)

    render(conn, "tile_errors.json", tile_errors: tile_changeset.errors)
  end

  def delete(conn, %{"id" => _id}) do
    level = conn.assigns.level

    Dungeons.delete_level!(level)

    conn
    |> put_flash(:info, "Level level deleted successfully.")
    |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.dungeon))
  end

  def level_edge(conn, %{"dungeon_id" => _dungeon_id, "edge" => edge, "level_number" => level_number}) do
    inverse_edge = case edge do
                     "north" -> "south"
                     "south" -> "north"
                     "east" -> "west"
                     "west" -> "east"
                   end

    adjacent_level_edge_tiles = Dungeons.level_edge_tiles(Dungeons.get_level(conn.assigns.dungeon.id, level_number), inverse_edge)

    render(conn, "adjacent_level_edge.json", edge: edge, adjacent_level_edge_tiles: adjacent_level_edge_tiles)
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

  defp assign_dungeon(conn, _opts) do
    dungeon =  Dungeons.get_dungeon!(conn.params["dungeon_id"])

    if dungeon.user_id == conn.assigns.current_user.id do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:dungeon, Repo.preload(dungeon, :levels))
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp assign_level(conn, _opts) do
    incoming_id = case Integer.parse(conn.params["id"]) do
                    {int, ""} -> int
                    str -> str
                  end
    level = Enum.find(conn.assigns.dungeon.levels, fn(level) -> level.id == incoming_id end)

    if level do
      conn
      |> assign(:level, Repo.preload(level, [tiles: :tile_template]))
    else
      conn
      |> put_flash(:error, "You do not have access to that")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp assign_tile_shortlist(conn, _opts) do
    conn
    |> assign(:tile_shortlist, TileShortlists.list_tiles(conn.assigns.current_user))
  end

  defp validate_updateable(conn, _opts) do
    if !conn.assigns.dungeon.active do
      conn
    else
      conn
      |> put_flash(:error, "Cannot edit an active dungeon")
      |> redirect(to: Routes.dungeon_path(conn, :show, conn.assigns.dungeon))
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

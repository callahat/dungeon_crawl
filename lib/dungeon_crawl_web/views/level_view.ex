defmodule DungeonCrawlWeb.LevelView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.StateValue.StandardVariables
  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawlWeb.LevelView
  alias DungeonCrawlWeb.SharedView

  def adjacent_selects(form, dungeons) do
    options = Enum.map(dungeons, &{"#{&1.number} #{&1.name}", &1.number})
    ["north", "south", "east", "west"]
    |> Enum.map(fn direction ->
       {:safe, label_html} = label(form, direction, class: "control-label")
       {:safe, select_html} = select(form, String.to_atom("number_#{direction}"), options, class: "form-control", prompt: "None")
       """
       <div class="form-group col-md-3">
         #{ label_html }
         #{ select_html }
       </div>
       """
       end)
    |> Enum.join("\n")
    |> _make_it_safe()
  end

  def tile_template_pres(tile_templates, historic \\ false) do
    tile_templates
    |> Enum.map(fn(tt) ->
         render_to_string(DungeonCrawlWeb.SharedView, "tile_template_pre.html", %{tile_template: tt, historic: historic, shortlist_id: tt.id})
       end)
    |> Enum.join("\n")
    |> _make_it_safe()
  end

  def color_tr(colors) do
    colors
    |> Enum.map(fn(c) ->
        ~s(<td data-color="#{ c }"><span name="paintable_color" style="background-color: #{ c }">&nbsp;&nbsp;</span></td>)
       end)
    |> Enum.join("\n")
    |> _wrap_tr()
    |> _make_it_safe()
  end

  defp _wrap_tr(rows) do
    "<tr>#{ rows }</tr>"
  end

  defp _make_it_safe(html) do
    {:safe, html}
  end

  def edges_json(adjacent_level_edge_tiles) do
    %{ north: edge_json(:north, adjacent_level_edge_tiles[:north]),
       south: edge_json(:south, adjacent_level_edge_tiles[:south]),
       east: edge_json(:east, adjacent_level_edge_tiles[:east]),
       west: edge_json(:west, adjacent_level_edge_tiles[:west])
    }
  end

  def edge_json(edge, adjacent_tile_edge) when edge in [:north, :south, "north", "south"] do
    (adjacent_tile_edge || [])
    |> Enum.map(fn tile -> %{"id" => "#{ edge }_#{ tile.col }", "html" => DungeonCrawlWeb.SharedView.tile_and_style(tile)} end)
  end
  def edge_json(edge, adjacent_tile_edge) when edge in [:east, :west, "east", "west"] do
    (adjacent_tile_edge || [])
    |> Enum.map(fn tile -> %{"id" => "#{ edge }_#{ tile.row }", "html" => DungeonCrawlWeb.SharedView.tile_and_style(tile)} end)
  end
  def edge_json(_, _), do: []

  def render("tile_errors.json", %{tile_errors: tile_errors, tile: tile}) do
    errors = Enum.map(tile_errors, fn {field, detail} ->
      %{
        field: field,
        detail: _render_detail(detail)
      }
    end)

    %{errors: errors, tile: Dungeons.copy_tile_fields(tile)}
  end

  def render("adjacent_level_edge.json", %{edge: edge, adjacent_level_edge_tiles: adjacent_level_edge_tiles}) do
    edge_json(edge, adjacent_level_edge_tiles)
  end

  defp _render_detail({message, values}) do
    Enum.reduce values, message, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end
  end
  defp _render_detail(message) do
    message
  end

  def tile_template_nav_tabs() do
    render_to_string(__MODULE__, "tile_list_navtabs.html", %{})
    |> _make_it_safe()
  end
  def tile_template_tabs(tile_templates) do
    TileTemplate.groups()
    |> Enum.map(fn group_name ->
         render_to_string(__MODULE__,
                 "tile_list_tab_content.html",
                 %{tile_templates: tile_templates,
                   group_name: group_name,
                   show_active: if(group_name == "terrain", do: " show active")})
       end)
    |> Enum.join("")
    |> _make_it_safe()
  end
end

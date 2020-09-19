defmodule DungeonCrawlWeb.DungeonMapView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Dungeon

  def tile_template_pres(tile_templates, historic \\ false) do
    tile_templates
    |> Enum.map(fn(tile_template) ->
         """
           <pre class="tile_template_preview embiggen"
                name="paintable_tile_template"
                title="#{ tile_template.name }"
                #{ if historic, do: " data-historic-template=true" }
                data-tile-template-id="#{ tile_template.id }"
                data-tile-template-description="#{ tile_template.description }"
                data-tile-template-state="#{ Phoenix.HTML.Safe.to_iodata tile_template.state }"
                data-tile-template-script="#{ Phoenix.HTML.Safe.to_iodata tile_template.script }"
                data-color="#{ tile_template.color }"
                data-background-color="#{ tile_template.background_color }"
                data-name="#{ Phoenix.HTML.Safe.to_iodata tile_template.name }"
                data-slug="#{ Phoenix.HTML.Safe.to_iodata tile_template.slug }"
                data-character="#{ Phoenix.HTML.Safe.to_iodata tile_template.character }"
                data-state="#{ Phoenix.HTML.Safe.to_iodata tile_template.state }"
                data-script="#{ Phoenix.HTML.Safe.to_iodata tile_template.script }">#{ DungeonCrawlWeb.SharedView.tile_and_style(tile_template) }</pre>
         """
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

  def render("map_tile_errors.json", %{map_tile_errors: map_tile_errors}) do
    errors = Enum.map(map_tile_errors, fn {field, detail} ->
      %{
        field: field,
        detail: _render_detail(detail)
      }
    end)

    %{errors: errors}
  end

  defp _render_detail({message, values}) do
    Enum.reduce values, message, fn {k, v}, acc ->
      String.replace(acc, "%{#{k}}", to_string(v))
    end
  end
  defp _render_detail(message) do
    message
  end
end

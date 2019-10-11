defmodule DungeonCrawlWeb.DungeonView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Dungeon

  def activate_or_new_version_button(conn, dungeon, location) do
    if dungeon.active do
      unless Dungeon.next_version_exists?(dungeon) do
        link "New Version", to: Routes.dungeon_new_version_path(conn, :new_version, dungeon), method: :post, data: [confirm: "Are you sure?"], class: "btn btn-info btn-xs"
      end
    else
      crawl_msg = if location, do: "Your current crawl will be lost, "
      [link("Test Crawl", to: Routes.dungeon_test_crawl_path(conn, :test_crawl, dungeon), method: :post, data: [confirm: "#{crawl_msg}Are you sure?"], class: "btn btn-info btn-xs"), " ",
      link("Activate", to: Routes.dungeon_activate_path(conn, :activate, dungeon), method: :put, data: [confirm: "Are you sure?"], class: "btn btn-info btn-xs")]
    end
  end

  def tile_template_pres(tile_templates, historic \\ false) do
    tile_templates
    |> Enum.map(fn(tile_template) ->
         """
           <pre class="tile_template_preview embiggen"
                name="paintable_tile_template"
                title="#{ tile_template.name }"
                #{ if historic, do: " data-historic-template=true" }
                data-tile-template-description="#{ tile_template.description }"
                data-tile-template-state="#{ tile_template.state }"
                data-tile-template-script="#{ tile_template.script }"
                data-color="#{ tile_template.color }"
                data-background-color="#{ tile_template.background_color }"
                data-tile-template-id="#{ tile_template.id }">#{ DungeonCrawlWeb.SharedView.tile_and_style(tile_template) }</pre>
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
end

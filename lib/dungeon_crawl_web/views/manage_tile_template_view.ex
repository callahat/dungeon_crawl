defmodule DungeonCrawlWeb.ManageTileTemplateView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.TileTemplates

  def activate_or_new_version_button(conn, tile_template) do
    if tile_template.active do
      unless TileTemplates.next_version_exists?(tile_template) do
        link "New Version",
             to: manage_tile_template_new_version_path(conn, :new_version, tile_template),
             method: :post,
             data: [confirm: "Are you sure?"],
             class: "btn btn-info btn-xs"
      end
    else
      link "Activate",
           to: manage_tile_template_activate_path(conn, :activate, tile_template),
           method: :put,
           data: [confirm: "Are you sure?"],
           class: "btn btn-info btn-xs"
    end
  end
end

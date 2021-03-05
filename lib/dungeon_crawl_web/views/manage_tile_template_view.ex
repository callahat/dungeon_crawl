defmodule DungeonCrawlWeb.ManageTileTemplateView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  def activate_or_new_version_button(conn, tile_template) do
    if tile_template.active do
      unless TileTemplates.next_version_exists?(tile_template) do
        link "New Version",
             to: Routes.manage_tile_template_new_version_path(conn, :new_version, tile_template),
             method: :post,
             data: [confirm: "Are you sure?"],
             class: "btn btn-info btn-sm"
      end
    else
      link "Activate",
           to: Routes.manage_tile_template_activate_path(conn, :activate, tile_template),
           method: :put,
           data: [confirm: "Are you sure?"],
           class: "btn btn-success btn-sm"
    end
  end

  def error_pre_tag(form, field) do
    if error = form.errors[field] do
      content_tag :pre, translate_error(error), class: "help-block"
    end
  end
end

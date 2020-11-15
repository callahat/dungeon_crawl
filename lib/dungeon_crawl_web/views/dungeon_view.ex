defmodule DungeonCrawlWeb.DungeonView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Dungeon

  def activate_or_new_version_button(conn, dungeon, location) do
    if dungeon.active do
      unless Dungeon.next_version_exists?(dungeon) do
        link "New Version", to: Routes.dungeon_new_version_path(conn, :new_version, dungeon), method: :post, data: [confirm: "Are you sure?"], class: "btn btn-info btn-sm"
      end
    else
      crawl_msg = if location, do: "Your current crawl will be lost, "
      [link("Test Crawl", to: Routes.dungeon_test_crawl_path(conn, :test_crawl, dungeon), method: :post, data: [confirm: "#{crawl_msg}Are you sure?"], class: "btn btn-info btn-sm"), " ",
      link("Activate", to: Routes.dungeon_activate_path(conn, :activate, dungeon), method: :put, data: [confirm: "Are you sure?"], class: "btn btn-success btn-sm")]
    end
  end

  def adjacent_map_names(dungeon) do
    names = Dungeon.adjacent_map_names(dungeon)
    {:safe,
      """
      <table class="table table-sm compact-table">
        <tr><td>North:</td><td>#{ names.north }</td></tr>
        <tr><td>South:</td><td>#{ names.south }</td></tr>
        <tr><td>West:</td><td>#{ names.west }</td></tr>
        <tr><td>East:</td><td>#{ names.east }</td></tr>
      </table>
      """
    }
  end
end

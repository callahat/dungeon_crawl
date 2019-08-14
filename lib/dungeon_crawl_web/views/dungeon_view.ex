defmodule DungeonCrawlWeb.DungeonView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Dungeon

  def activate_or_new_version_button(conn, dungeon, location) do
    if dungeon.active do
      unless Dungeon.next_version_exists?(dungeon) do
        link "New Version", to: dungeon_new_version_path(conn, :new_version, dungeon), method: :post, data: [confirm: "Are you sure?"], class: "btn btn-info btn-xs"
      end
    else
      crawl_msg = if location, do: "Your current crawl will be lost, "
      [link("Test Crawl", to: dungeon_test_crawl_path(conn, :test_crawl, dungeon), method: :post, data: [confirm: "#{crawl_msg}Are you sure?"], class: "btn btn-info btn-xs"), " ",
      link("Activate", to: dungeon_activate_path(conn, :activate, dungeon), method: :put, data: [confirm: "Are you sure?"], class: "btn btn-info btn-xs")]
    end
  end
end

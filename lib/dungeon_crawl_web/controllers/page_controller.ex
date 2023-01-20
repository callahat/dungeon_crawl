defmodule DungeonCrawlWeb.PageController do
  use DungeonCrawl.Web, :controller

  def index(conn, _params) do
    redirect(conn, to: Routes.dungeon_path(conn, :index))
  end

  def reference(conn, _params) do
    render conn, "reference.html"
  end
end

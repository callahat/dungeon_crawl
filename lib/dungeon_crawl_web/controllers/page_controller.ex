defmodule DungeonCrawlWeb.PageController do
  use DungeonCrawl.Web, :controller

  def index(conn, _params) do
    redirect(conn, to: Routes.crawler_path(conn, :show))
  end

  def reference(conn, _params) do
    render conn, "reference.html"
  end
end

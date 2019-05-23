defmodule DungeonCrawlWeb.PageController do
  use DungeonCrawl.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end

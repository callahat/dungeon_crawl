defmodule DungeonCrawlWeb.PageController do
  use DungeonCrawl.Web, :controller

  plug :set_sidebar_col when action in [:reference]

  def index(conn, _params) do
    render conn, "index.html"
  end

  def reference(conn, _params) do
    render conn, "reference.html"
  end

  defp set_sidebar_col(conn, _opts) do
    conn
    |> assign(:sidebar_col, 2)
  end
end

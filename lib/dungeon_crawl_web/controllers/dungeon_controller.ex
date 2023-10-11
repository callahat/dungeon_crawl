defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  plug :validate_not_crawling
  plug :validate_logged_in when action in [:saved_games]

  def index(conn, _opt) do
    assign(conn, :user_id_hash, conn.assigns.user_id_hash)
    |> assign(:focus_dungeon_id, Plug.Conn.get_session(conn, :focus_dungeon_id))
    |> Plug.Conn.put_session(:focus_dungeon_id, nil)
    |> assign(:controller_csrf, Phoenix.Controller.get_csrf_token())
    |> render("index.html")
  end

  def saved_games(conn, _opt) do
    assign(conn, :user_id_hash, conn.assigns.user_id_hash)
    |> assign(:controller_csrf, Phoenix.Controller.get_csrf_token())
    |> render("saved_games.html")
  end

  defp validate_not_crawling(conn, _opts) do
    unless conn.assigns.is_crawling? do
      conn
    else
      conn
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_logged_in(conn, _opts) do
    if conn.assigns.current_user == nil do
      conn
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    else
      conn
    end
  end
end

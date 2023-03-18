defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Player

  plug :assign_player_location
  plug :validate_not_crawling
  plug :validate_logged_in when action in [:saved_games]

  def index(conn, _opt) do
    assign(conn, :user_id_hash, conn.assigns.user_id_hash)
    |> assign(:controller_csrf, Phoenix.Controller.get_csrf_token())
    |> render("index.html")
  end

  def saved_games(conn, _opt) do
    assign(conn, :user_id_hash, conn.assigns.user_id_hash)
    |> assign(:controller_csrf, Phoenix.Controller.get_csrf_token())
    |> render("saved_games.html")
  end

  defp assign_player_location(conn, _opts) do
    # TODO: get this from the instance?
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(tile: [:level])

    conn
    |> assign(:player_location, player_location)
  end

  defp validate_not_crawling(conn, _opts) do
    # TODO: make use of the flag set set by Auth
    if conn.assigns.player_location == nil do
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

defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeons

  plug :assign_player_location # when action in [:show, :create, :avatar, :validate_avatar, :invite, :validate_invite, :destroy]
  plug :validate_not_crawling when action in [:index]

  def index(conn, _opt) do
    dungeons = Dungeons.list_active_dungeons_with_player_count()
               |> Enum.map(fn(%{dungeon: dungeon}) -> Repo.preload(dungeon, [:levels, :locations, :dungeon_instances]) end)

    render(conn, "index.html", dungeons: dungeons)
  end


  def dungeon_list_live(conn, _opt) do
    assign(conn, :user_id_hash, conn.assigns.user_id_hash)
    |> render("dungeon.html")
  end

  defp assign_player_location(conn, _opts) do
    # TODO: get this from the instance?
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(tile: [:level])

    conn
    |> assign(:player_location, player_location)
  end

  defp validate_not_crawling(conn, _opts) do
    if conn.assigns.player_location == nil do
      conn
    else
      conn
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end
end

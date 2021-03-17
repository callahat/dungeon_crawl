defmodule DungeonCrawlWeb.TileShortlistController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.TileShortlists

  plug :authenticate_user

  def create(conn, %{"tile_shortlist" => tile_shortlist_params}) do
    case TileShortlists.add_to_shortlist(conn.assigns.current_user, tile_shortlist_params) do
      {:ok, tile_shortlist} ->
        render(conn, "tile_shortlist.json", tile_shortlist: tile_shortlist)
      {:error, changeset} ->
        render(conn, "tile_shortlist.json", errors: changeset.errors)
    end
  end
end


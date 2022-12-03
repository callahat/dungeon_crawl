defmodule DungeonCrawlWeb.PageControllerTest do
  use DungeonCrawlWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert redirected_to(conn) == crawler_path(conn, :index)
  end

  test "GET /reference", %{conn: conn} do
    conn = get conn, "/reference"
    assert html_response(conn, 200) =~ "The dungeon is a collection of levels. It is at the top of the heirarchy,"
  end
end

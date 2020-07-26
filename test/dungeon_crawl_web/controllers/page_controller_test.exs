defmodule DungeonCrawlWeb.PageControllerTest do
  use DungeonCrawlWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "Welcome to Phoenix!"
  end

  test "GET /reference", %{conn: conn} do
    conn = get conn, "/reference"
    assert html_response(conn, 200) =~ "The dungeon map is a collection of map tiles. The visible representation is only in two dimensions"
  end
end

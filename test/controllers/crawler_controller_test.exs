defmodule DungeonCrawl.CrawlerControllerTest do
  use DungeonCrawl.ConnCase

#  test "lists all entries on index", %{conn: conn} do
#    conn = get conn, crawler_path(conn, :index)
#    assert html_response(conn, 200) =~ "Listing crawler"
#  end

#  test "renders form for new resources", %{conn: conn} do
#    conn = get conn, crawler_path(conn, :new)
#    assert html_response(conn, 200) =~ "New crawler"
#  end

#  test "creates resource and redirects when data is valid", %{conn: conn} do
#    conn = post conn, crawler_path(conn, :create), crawler: @valid_attrs
#    assert redirected_to(conn) == crawler_path(conn, :index)
#    assert Repo.get_by(Crawler, @valid_attrs)
#  end

#  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
#    conn = post conn, crawler_path(conn, :create), crawler: @invalid_attrs
#    assert html_response(conn, 200) =~ "New crawler"
#  end

#  test "shows chosen resource", %{conn: conn} do
#    crawler = Repo.insert! %Crawler{}
#    conn = get conn, crawler_path(conn, :show, crawler)
#    assert html_response(conn, 200) =~ "Show crawler"
#  end

#  test "renders page not found when id is nonexistent", %{conn: conn} do
#    assert_error_sent 404, fn ->
#      get conn, crawler_path(conn, :show, -1)
#    end
#  end

#  test "renders form for editing chosen resource", %{conn: conn} do
#    crawler = Repo.insert! %Crawler{}
#    conn = get conn, crawler_path(conn, :edit, crawler)
#    assert html_response(conn, 200) =~ "Edit crawler"
#  end

#  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
#    crawler = Repo.insert! %Crawler{}
#    conn = put conn, crawler_path(conn, :update, crawler), crawler: @valid_attrs
#    assert redirected_to(conn) == crawler_path(conn, :show, crawler)
#    assert Repo.get_by(Crawler, @valid_attrs)
#  end

#  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
#    crawler = Repo.insert! %Crawler{}
#    conn = put conn, crawler_path(conn, :update, crawler), crawler: @invalid_attrs
#    assert html_response(conn, 200) =~ "Edit crawler"
#  end

#  test "deletes chosen resource", %{conn: conn} do
#    crawler = Repo.insert! %Crawler{}
#    conn = delete conn, crawler_path(conn, :delete, crawler)
#    assert redirected_to(conn) == crawler_path(conn, :index)
#    refute Repo.get(Crawler, crawler.id)
#  end
end

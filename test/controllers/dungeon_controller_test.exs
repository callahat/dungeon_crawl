defmodule DungeonCrawl.DungeonControllerTest do
  use DungeonCrawl.ConnCase

  alias DungeonCrawl.Dungeon
  @valid_attrs %{name: "some content"}
  @invalid_attrs %{}

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing dungeons"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :new)
    assert html_response(conn, 200) =~ "New dungeon"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, dungeon_path(conn, :create), dungeon: @valid_attrs
    assert redirected_to(conn) == dungeon_path(conn, :index)
    assert Repo.get_by(Dungeon, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, dungeon_path(conn, :create), dungeon: @invalid_attrs
    assert html_response(conn, 200) =~ "New dungeon"
  end

  test "shows chosen resource", %{conn: conn} do
    dungeon = Repo.insert! %Dungeon{}
    conn = get conn, dungeon_path(conn, :show, dungeon)
    assert html_response(conn, 200) =~ "Show dungeon"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, dungeon_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    dungeon = Repo.insert! %Dungeon{}
    conn = get conn, dungeon_path(conn, :edit, dungeon)
    assert html_response(conn, 200) =~ "Edit dungeon"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    dungeon = Repo.insert! %Dungeon{}
    conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @valid_attrs
    assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
    assert Repo.get_by(Dungeon, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    dungeon = Repo.insert! %Dungeon{}
    conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit dungeon"
  end

  test "deletes chosen resource", %{conn: conn} do
    dungeon = Repo.insert! %Dungeon{}
    conn = delete conn, dungeon_path(conn, :delete, dungeon)
    assert redirected_to(conn) == dungeon_path(conn, :index)
    refute Repo.get(Dungeon, dungeon.id)
  end
end

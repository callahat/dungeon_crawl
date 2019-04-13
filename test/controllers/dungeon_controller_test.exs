defmodule DungeonCrawl.DungeonControllerTest do
  use DungeonCrawl.ConnCase

  alias DungeonCrawl.Dungeon
  @valid_attrs %{name: "some content"}
  @invalid_attrs %{}

  setup %{conn: conn} = config do
    case config do
      %{nouser: true} -> :ok
      _    ->
        user = insert_user(%{username: config[:login_as] || "CSwaggins", is_admin: !config[:not_admin]})
        conn = assign(build_conn(), :current_user, user)
        {:ok, conn: conn, user: user}
    end
  end

  # TODO: test that non admins can't access anything here?
  @tag login_as: "notadmin", not_admin: true
  test "redirects non admin users", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :index)
    assert redirected_to(conn) == page_path(conn, :index)
  end

  @tag nouser: true
  test "redirects non users", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :index)
    assert redirected_to(conn) == page_path(conn, :index)
  end

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
    assert redirected_to(conn) == dungeon_path(conn, :show, Repo.get_by(Dungeon, @valid_attrs))
    assert Repo.get_by(Dungeon, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, dungeon_path(conn, :create), dungeon: @invalid_attrs
    assert html_response(conn, 200) =~ "New dungeon"
  end

  test "shows chosen resource", %{conn: conn} do
    dungeon = insert_dungeon()
    conn = get conn, dungeon_path(conn, :show, dungeon)
    assert html_response(conn, 200) =~ "Dungeon: "
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, dungeon_path(conn, :show, -1)
    end
  end

  test "deletes chosen resource", %{conn: conn} do
    dungeon = insert_dungeon()
    conn = delete conn, dungeon_path(conn, :delete, dungeon)
    assert redirected_to(conn) == dungeon_path(conn, :index)
    refute Repo.get(Dungeon, dungeon.id)
  end
end

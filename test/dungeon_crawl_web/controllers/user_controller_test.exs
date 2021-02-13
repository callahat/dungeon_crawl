defmodule DungeonCrawlWeb.UserControllerTest do
  use DungeonCrawlWeb.ConnCase
  alias DungeonCrawl.Account.User
  alias DungeonCrawl.TileShortlists

  import Plug.Conn, only: [assign: 3, get_session: 2]

  @valid_attrs %{name: "some content", password: "some content", username: "some content"}
  @invalid_attrs %{name: ""}

  setup %{conn: conn} = config do
    if username = config[:login_as] do
      user = insert_user(%{username: username})
      conn = assign(build_conn(), :current_user, user)
      {:ok, conn: conn, user: user}
    else
      {:ok, conn: conn}
    end
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, user_path(conn, :new)
    assert html_response(conn, 200) =~ "New user"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @valid_attrs
    assert redirected_to(conn) == page_path(conn, :index)
    assert user = Repo.get_by(User, Map.delete(@valid_attrs, :password))
    assert length(TileShortlists.list_tiles(user)) == 16
  end

  test "generates the user_id_hash from the session", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @valid_attrs
    user = Repo.get_by(User, Map.delete(@valid_attrs, :password))
    assert String.length(user.user_id_hash) > 10
    assert user.user_id_hash == get_session(conn, :user_id_hash)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: @invalid_attrs
    assert html_response(conn, 200) =~ "New user"
  end

  test "does not allow is_admin to be set to true", %{conn: conn} do
    conn = post conn, user_path(conn, :create), user: Map.put(@valid_attrs, :is_admin, true)
    refute Repo.get_by(User, Map.delete(@valid_attrs, :password)).is_admin
    assert redirected_to(conn) == page_path(conn, :index)
    assert Repo.get_by(User, Map.delete(@valid_attrs, :password))
  end

  @tag login_as: "maxheadroom"
  test "shows the current resource", %{conn: conn, user: _user} do
    conn = get conn, user_path(conn, :show)
    assert html_response(conn, 200) =~ "Show user"
  end

  @tag login_as: "maxheadroom"
  test "renders form for editing current resource", %{conn: conn, user: _user} do
    conn = get conn, user_path(conn, :edit)
    assert html_response(conn, 200) =~ "Edit user"
  end

  @tag login_as: "maxheadroom"
  test "updates chosen resource and redirects when data is valid", %{conn: conn, user: _user} do
    conn = put conn, user_path(conn, :update), user: @valid_attrs
    assert redirected_to(conn) == user_path(conn, :show)
    assert Repo.get_by(User, Map.delete(@valid_attrs, :password))
  end

  @tag login_as: "maxheadroom"
  test "does not allow is_admin to be updated to true", %{conn: conn} do
    conn = put conn, user_path(conn, :update), user: Map.put(@valid_attrs, :is_admin, true)
    assert redirected_to(conn) == user_path(conn, :show)
    refute Repo.get_by(User, Map.delete(@valid_attrs, :password)).is_admin
  end

  @tag login_as: "maxheadroom"
  test "does not update current resource and renders errors when data is invalid", %{conn: conn, user: _user} do
    conn = put conn, user_path(conn, :update), user: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit user"
  end

  @tag login_as: "maxheadroom"
  test "deletes current resource", %{conn: conn, user: user} do
    conn = delete conn, user_path(conn, :delete)
    assert redirected_to(conn) == page_path(conn, :index)
    refute Repo.get(User, user.id)
  end
end

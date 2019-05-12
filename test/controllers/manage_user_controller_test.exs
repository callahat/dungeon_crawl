defmodule DungeonCrawlWeb.ManageUserControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawlWeb.User
  @valid_attrs %{name: "some content", password: "some content", username: "some content", is_admin: true}
  @invalid_attrs %{name: ""}

  setup %{conn: conn} = config do
    if username = config[:login_as] do
      user = insert_user(%{username: username, is_admin: !config[:not_admin]})
      conn = assign(build_conn(), :current_user, user)
      {:ok, conn: conn, user: user}
    else
      :ok
    end
  end

  @tag login_as: "notadmin", not_admin: true
  test "redirects non admin users", %{conn: conn} do
    conn = get conn, manage_user_path(conn, :index)
    assert redirected_to(conn) == page_path(conn, :index)
  end


  @tag login_as: "maxheadroom"
  test "lists all entries on index", %{conn: conn} do
    conn = get conn, manage_user_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing users"
  end

  @tag login_as: "maxheadroom"
  test "renders form for new resources", %{conn: conn} do
    conn = get conn, manage_user_path(conn, :new)
    assert html_response(conn, 200) =~ "New user"
  end

  @tag login_as: "maxheadroom"
  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, manage_user_path(conn, :create), user: @valid_attrs
    assert redirected_to(conn) == manage_user_path(conn, :index)
    new_user = Repo.get_by(User, Map.delete(@valid_attrs, :password))
    assert new_user
    assert new_user.user_id_hash != nil
  end

  @tag login_as: "maxheadroom"
  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, manage_user_path(conn, :create), user: @invalid_attrs
    assert html_response(conn, 200) =~ "New user"
  end

  @tag login_as: "maxheadroom"
  test "shows chosen resource", %{conn: conn, user: _user} do
    target_user = insert_user @valid_attrs
    conn = get conn, manage_user_path(conn, :show, target_user)
    assert html_response(conn, 200) =~ "Show user"
  end

  @tag login_as: "maxheadroom"
  test "renders page not found when id is nonexistent", %{conn: conn, user: _user} do
    assert_error_sent 404, fn ->
      get conn, manage_user_path(conn, :show, -1)
    end
  end

  @tag login_as: "maxheadroom"
  test "renders form for editing chosen resource", %{conn: conn, user: _user} do
    target_user = insert_user @valid_attrs
    conn = get conn, manage_user_path(conn, :edit, target_user)
    assert html_response(conn, 200) =~ "Edit user"
  end

  @tag login_as: "maxheadroom"
  test "updates chosen resource and redirects when data is valid", %{conn: conn, user: _user} do
    target_user = insert_user @valid_attrs
    conn = put conn, manage_user_path(conn, :update, target_user), user: @valid_attrs
    assert redirected_to(conn) == manage_user_path(conn, :show, target_user)
    assert Repo.get_by(User, Map.delete(@valid_attrs, :password))
  end

  @tag login_as: "maxheadroom"
  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn, user: _user} do
    target_user = insert_user @valid_attrs
    conn = put conn, manage_user_path(conn, :update, target_user), user: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit user"
  end

  @tag login_as: "maxheadroom"
  test "deletes chosen resource", %{conn: conn, user: _user} do
    target_user = insert_user @valid_attrs
    conn = delete conn, manage_user_path(conn, :delete, target_user)
    assert redirected_to(conn) == manage_user_path(conn, :index)
    refute Repo.get(User, target_user.id)
  end
end

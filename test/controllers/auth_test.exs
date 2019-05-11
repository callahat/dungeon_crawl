defmodule DungeonCrawl.AuthTest do
  use DungeonCrawl.ConnCase
  alias DungeonCrawl.Auth

  setup %{conn: conn} do
    conn = conn
      |> bypass_through(DungeonCrawl.Router, :browser)
      |> get("/")

    {:ok, %{conn: conn}}
  end

  test "authenticate_user halts when no current_user exists", %{conn: conn} do
    conn = Auth.authenticate_user(conn, [])
    assert conn.halted
  end

  test "authenticate_user continues when the current user exists", %{conn: conn} do
    conn = 
      conn
      |> assign(:current_user, %DungeonCrawl.User{})
      |> Auth.authenticate_user([])

    refute conn.halted
  end

  test "verify_user_is_admin halts when the current user does not exist", %{conn: conn} do
    conn = Auth.verify_user_is_admin(conn, [])
    assert conn.halted
  end

  test "verify_user_is_admin halts when the current user is not an admin", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, %DungeonCrawl.User{})
      |> Auth.verify_user_is_admin([])

    assert conn.halted
  end

  test "verify_user_is_admin continues when the current user is an admin", %{conn: conn} do
    conn =
      conn
      |> assign(:current_user, %DungeonCrawl.User{is_admin: true})
      |> Auth.verify_user_is_admin([])

    refute conn.halted
  end

  test "login puts the user in the session", %{conn: conn} do
    login_conn =
      conn
      |> Auth.login(%DungeonCrawl.User{id: 123, user_id_hash: "asdf"})
      |> send_resp(:ok,"")

    next_conn = get(login_conn, "/")
    assert get_session(next_conn, :user_id) == 123
    assert get_session(next_conn, :user_id_hash) == "asdf"
  end

  test "logout drops the session", %{conn: conn} do
    logout_conn = 
      conn
      |> put_session(:user_id, 123)
      |> put_session(:user_id_hash, "asdf")
      |> Auth.logout()
      |> send_resp(:ok, "")

    next_conn = get(logout_conn, "/")
    refute get_session(next_conn, :user_id)
    assert get_session(next_conn, :user_id_hash)
    assert get_session(next_conn, :user_id_hash) != "asdf"
  end

  test "call places the user from the session into assigns", %{conn: conn} do
    user = insert_user()
    conn = 
      conn
      |> put_session(:user_id, user.id)
      |> Auth.call(Repo)

    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.user_id_hash == user.user_id_hash
  end

  test "call with no session sets the current_user assign to nil", %{conn: conn} do
    conn = Auth.call(conn, Repo)
    assert conn.assigns.current_user == nil
  end

  test "call with no session sets the user_id_hash", %{conn: conn} do
    conn = Auth.call(conn, Repo)

    assert get_session(conn, :user_id_hash)
    assert conn.assigns.user_id_hash == get_session(conn, :user_id_hash)
  end

  test "login with a valid username and password", %{conn: conn} do
    user = insert_user(%{username: "me", password: "secret"})
    {:ok, conn} = Auth.login_by_username_and_pass(conn, "me", "secret", repo: Repo)

    assert conn.assigns.current_user.id == user.id
    assert conn.assigns.user_id_hash == user.user_id_hash
  end

  test "login with a not found user", %{conn: conn} do
    assert {:error, :not_found, _conn} = Auth.login_by_username_and_pass(conn, "me", "secret", repo: Repo)
  end

  test "login with password mismatch", %{conn: conn} do
    _ = insert_user(%{username: "me", password: "secret"})
    {:error, :unauthorized, _conn} = Auth.login_by_username_and_pass(conn, "me", "fatfingers", repo: Repo)
  end
end

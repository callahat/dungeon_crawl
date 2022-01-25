defmodule DungeonCrawlWeb.Auth do
  import Plug.Conn
  import Bcrypt, only: [verify_pass: 2, no_user_verify: 0]
  import Phoenix.Controller
  alias DungeonCrawlWeb.Router.Helpers
  alias DungeonCrawl.Account

  def init(opts) do
    Keyword.fetch!(opts, :repo)
  end

  def call(conn, repo) do
    user_id = get_session(conn, :user_id)

    cond do
      user = conn.assigns[:current_user] ->
        put_current_user(conn, user)
      user = user_id && Account.get_user(user_id, repo) ->
        put_current_user(conn, user)
      user_id_hash = conn.assigns[:user_id_hash] ->
        put_guest_user(conn, user_id_hash)
      user_id_hash = get_session(conn, :user_id_hash) ->
        put_guest_user(conn, user_id_hash)
      true ->
        user_id_hash = :base64.encode(:crypto.strong_rand_bytes(24))
        put_session(conn, :user_id_hash, user_id_hash)
        |> put_guest_user(user_id_hash)
    end
  end

  def login(conn, user) do
    conn
    |> put_current_user(user)
    |> put_session(:user_id, user.id)
    |> put_session(:user_id_hash, user.user_id_hash)
    |> configure_session(renew: true)
  end

  defp put_current_user(conn, user) do
    conn
    |> assign(:current_user, user)
    |> assign(:user_id_hash, user.user_id_hash)
    |> put_token(user.user_id_hash)
  end

  defp put_token(conn, user_id_hash) do
    token = Phoenix.Token.sign(conn, "user hash socket", user_id_hash)

    conn
    |> assign(:user_token, token)
  end
 
  defp put_guest_user(conn, user_id_hash) do
    assign(conn, :current_user, nil)
    |> put_token(user_id_hash)
    |> assign(:user_id_hash, user_id_hash)
    |> configure_session(renew: true)
  end

  def logout(conn) do
    configure_session(conn, drop: true)
  end

  def login_by_username_and_pass(conn, username, given_pass, opts) do
    repo = Keyword.fetch!(opts, :repo)
    user = Account.get_by_username(username, repo)

    cond do
      user && verify_pass(given_pass, user.password_hash) ->
        {:ok, login(conn, user)}
      user ->
        {:error, :unauthorized, conn}
      true ->
        no_user_verify()
        {:error, :not_found, conn}
    end
  end

  def authenticate_user(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access that page")
      |> redirect(to: Helpers.page_path(conn, :index))
      |> halt()
    end
  end

  def verify_user_is_admin(conn, _opts) do
    if conn.assigns.current_user && conn.assigns.current_user.is_admin do
      conn
    else
      conn
      |> put_flash(:error, "You may not see that page")
      |> redirect(to: Helpers.page_path(conn, :index))
      |> halt()
    end
  end
end

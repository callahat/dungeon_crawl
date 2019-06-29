defmodule DungeonCrawlWeb.ManageUserController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Account
  alias DungeonCrawl.Account.User

  def index(conn, _params) do
    users = Account.list_users
    render(conn, "index.html", users: users)
  end

  def new(conn, _params) do
    changeset = Account.change_admin_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Account.create_admin(_registration_params(user_params)) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: manage_user_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp _registration_params(user_params) do
    Map.put(user_params, "user_id_hash", Account.extract_user_id_hash(%{assigns: %{}}))
  end

  def show(conn, %{"id" => id}) do
    user = Account.get_user!(id)
    render(conn, "show.html", user: user)
  end

  def edit(conn, %{"id" => id}) do
    user = Account.get_user!(id)
    changeset = Account.change_admin(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    user = Account.get_user!(id)

    case Account.update_admin(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: manage_user_path(conn, :show, user))
      {:error, changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    user =  Account.get_user!(id)

    case Account.delete_user(user) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User deleted successfully.")
        |> redirect(to: manage_user_path(conn, :index))
    end
  end
end

defmodule DungeonCrawlWeb.UserController do
  use DungeonCrawl.Web, :controller

  plug :authenticate_user when action in [:show, :edit, :update, :delete]

  alias DungeonCrawl.Account
  alias DungeonCrawl.Account.User
  alias DungeonCrawl.TileTemplates.TileTemplate

  def new(conn, _params) do
    changeset = Account.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Account.create_user(_registration_params(conn, user_params)) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: Routes.page_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  defp _registration_params(conn, user_params) do
    Map.put(user_params, "user_id_hash", Account.extract_user_id_hash(conn))
  end

  def show(conn, _) do
    user = Account.get_user!(conn.assigns.current_user.id)
    avatar = %TileTemplate{character: "@", color: user.color, background_color: user.background_color}
    render(conn, "show.html", user: user, avatar: avatar)
  end

  def edit(conn, _) do
    user = Account.get_user!(conn.assigns.current_user.id)
    changeset = Account.change_user(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    user = Account.get_user!(conn.assigns.current_user.id)

    case Account.update_user(user, user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: Routes.user_path(conn, :show))
      {:error, changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, _) do
    user = Account.get_user!(conn.assigns.current_user.id)

    case Account.delete_user(user) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User deleted successfully.")
        |> redirect(to: Routes.page_path(conn, :index))
    end
  end
end

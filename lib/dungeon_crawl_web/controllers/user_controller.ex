defmodule DungeonCrawlWeb.UserController do
  use DungeonCrawl.Web, :controller

  plug :authenticate_user when action in [:show, :edit, :update, :delete]

  alias DungeonCrawlWeb.User

  def new(conn, _params) do
    changeset = User.changeset(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    changeset = User.registration_changeset(%User{}, user_params) |> User.put_user_id_hash(conn.assigns[:user_id_hash])

    case Repo.insert(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: page_path(conn, :index))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, _) do
    user = Repo.get!(User, conn.assigns.current_user.id)
    render(conn, "show.html", user: user)
  end

  def edit(conn, _) do
    user = Repo.get!(User, conn.assigns.current_user.id)
    changeset = User.changeset(user)
    render(conn, "edit.html", user: user, changeset: changeset)
  end

  def update(conn, %{"user" => user_params}) do
    user = Repo.get!(User, conn.assigns.current_user.id)
    changeset = User.changeset(user, user_params)

    case Repo.update(changeset) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "User updated successfully.")
        |> redirect(to: user_path(conn, :show))
      {:error, changeset} ->
        render(conn, "edit.html", user: user, changeset: changeset)
    end
  end

  def delete(conn, _) do
    user = Repo.get!(User, conn.assigns.current_user.id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(user)

    conn
    |> DungeonCrawlWeb.Auth.logout
    |> put_flash(:info, "User deleted successfully.")
    |> redirect(to: page_path(conn, :index))
  end
end

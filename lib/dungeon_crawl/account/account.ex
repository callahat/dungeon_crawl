defmodule DungeonCrawl.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  If the exclaimation version is used and the User does not exist,
  raises `Ecto.NoResultsError`, otherwise `nil` is returned.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user(id, repo \\ Repo)
  def get_user(nil, _repo), do: nil
  def get_user(id, repo),  do: repo.get(User, id)
  def get_user!(id, repo \\ Repo)
  def get_user!(nil, _repo), do: nil
  def get_user!(id, repo), do: repo.get!(User, id)

  @doc """
  Gets a single user by their username.

  If the exclaimation version is used and the User does not exist,
  raises `Ecto.NoResultsError`, otherwise `nil` is returned.

  ## Examples

      iex> get_by_username("Doc")
      %User{}

      iex> get_by_username("RealFakeUser")
      nil

      iex> get_by_username!("Doc")
      %User{}

      iex> get_by_username!("RealFakeUser")
      ** (Ecto.NoResultsError)

  """
  def get_by_username(username, repo \\ Repo),  do: repo.get_by(User, username: username)
  def get_by_username!(username, repo \\ Repo), do: repo.get_by!(User, username: username)

  @doc """
  Gets a single user by their user_id_hash, if it exists.

  ## Examples

      iex> get_by_username("RealFakeUser")
      nil

      iex> get_by_username!("Doc")
      %User{}
  """
  def get_by_user_id_hash(user_id_hash, repo \\ Repo),  do: repo.get_by(User, user_id_hash: user_id_hash)

  @doc """
  Returns the displayable name for the given user. When no name exists, "AnonPlayer" is returned.

  ## Examples

    iex> get_name(%User{name: "bob"})
    "bob"

    iex> get_name("useridhash")
    "J04n"

    iex> get_name("hashnoaccount")
    "AnonPlayer"
  """
  def get_name(%User{name: name}), do: name
  def get_name(nil), do: "AnonPlayer"
  def get_name(user_id_hash, repo \\ Repo), do: get_name(repo.get_by(User, user_id_hash: user_id_hash))

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an admin user. Similar to `create_user` but `is_admin` can be set to true or false
  """
  def create_admin(attrs \\ %{}) do
    %User{}
    |> User.admin_registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates an admin. Similar to `update_user` but `is_admin` can be set to true or false.
  """
  def update_admin(%User{} = user, attrs) do
    user
    |> User.admin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a User.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes. Similar to `change_user` but does stuff with password.
  """
  def change_user_registration(%User{} = user) do
    User.registration_changeset(user, %{})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user registration changes. Similar to `change_user` but does stuff with password and is_admin.
  """
  def change_admin_registration(%User{} = user) do
    User.admin_registration_changeset(user, %{})
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking admin changes. Similar to `change_user` but allows `is_admin` to be set
  """
  def change_admin(%User{} = user) do
    User.admin_changeset(user, %{})
  end

  @doc """
  Returns the user_id_hash stored in the connection, or generates a new one.
  """
  def extract_user_id_hash(conn) do
    conn.assigns[:user_id_hash] || :base64.encode(:crypto.strong_rand_bytes(24))
  end
end

defmodule DungeonCrawl.Account.UserTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Account.User

  @valid_attrs %{name: "some content", password_hash: "some content", username: "some content"}
  @invalid_attrs %{}

  test "converts unique_constraint on username to error" do
    insert_user(%{username: "eric"})
    attrs = Map.put(@valid_attrs, :username, "eric")
    changeset = User.changeset(%User{}, attrs)

    assert {:error, changeset} = Repo.insert(changeset)
    assert {:username, {"has already been taken", [constraint: :unique, constraint_name: "users_username_index"]}} in changeset.errors
  end

  test "changeset with valid attributes" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset does not accept long usernames" do
    attrs = User.changeset(%User{}, %{@valid_attrs | username: String.duplicate("A", 30)})
    assert {:username, ["should be at most 20 character(s)"]} in
           errors_on(attrs)
  end

  test "registration_changeset password must be 6 characters long" do
    attrs = Map.put(@valid_attrs, :password, "a")
    changeset = User.registration_changeset(%User{}, attrs)
    assert {:password, {"should be at least %{count} character(s)", count: 6, validation: :length, kind: :min, type: :string}} in changeset.errors
  end

  test "registration_changeset with valid attrs hashes password" do
    attrs = Map.merge(@valid_attrs, %{password: "123456", user_id_hash: "goodhash"})
    changeset = User.registration_changeset(%User{}, attrs)
    %{password: pass, password_hash: pass_hash, user_id_hash: "goodhash"} = changeset.changes

    assert changeset.valid?
    assert pass_hash
    assert Comeonin.Bcrypt.checkpw(pass, pass_hash)
  end

  test "registration_changeset does not let is_admin be set" do
    attrs = Map.put(@valid_attrs, :is_admin, true)
    changeset = User.registration_changeset(%User{}, attrs)

    refute changeset.changes |> Map.has_key?(:is_admin)
  end

  test "admin_changeset lets is_admin be set" do
    attrs = Map.put(@valid_attrs, :is_admin, true)
    changeset = User.admin_changeset(%User{}, attrs)

    assert %{is_admin: true} = changeset.changes
  end

  test "put_user_id_hash into changeset" do
    changeset = User.changeset(%User{}, @valid_attrs) |> User.put_user_id_hash("GOODHASH")
    assert changeset.valid?
    assert %{user_id_hash: "GOODHASH"} = changeset.changes
  end

  test "generates a user_id_hash if none given" do
    changeset = User.changeset(%User{}, @valid_attrs) |> User.put_user_id_hash()
    assert changeset.valid?
    assert %{user_id_hash: hash} = changeset.changes
    assert String.length(hash) > 10
  end
end

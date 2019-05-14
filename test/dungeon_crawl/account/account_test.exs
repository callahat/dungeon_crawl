defmodule DungeonCrawl.AccountTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Account

  describe "users" do
    alias DungeonCrawl.Account.User

    @valid_attrs %{name: "some content", password: "password", username: "some content"}
    @admin_attrs %{name: "some content", password: "password", username: "some content", is_admin: true}
    @update_attrs %{name: "some updated name", is_admin: true}
    @invalid_attrs %{name: "junk", password: "no"}

    def user_fixture(attrs \\ %{}) do
      {:ok, user} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Account.create_user()

      user |> Map.put(:password, nil)
    end

    test "list_users/0 returns all users" do
      user = user_fixture()
      assert Account.list_users() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Account.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      assert {:ok, %User{} = user} = Account.create_user(@valid_attrs)
      assert user.name == "some content"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_user(@invalid_attrs)
    end

    test "create_admin/1 with valid data creates an admin user" do
      assert {:ok, %User{} = user} = Account.create_admin(@admin_attrs)
      assert user.name == "some content"
      assert user.is_admin == true
    end

    test "create_admin/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Account.create_admin(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, user} = Account.update_user(user, @update_attrs)
      assert %User{} = user
      assert user.name == "some updated name"
      refute user.is_admin
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Account.update_user(user, @invalid_attrs)
      assert user == Account.get_user!(user.id)
    end

    test "update_admin/2 with valid data updates the user" do
      user = user_fixture()
      assert {:ok, user} = Account.update_admin(user, Map.merge(@update_attrs, %{is_admin: true}))
      assert %User{} = user
      assert user.name == "some updated name"
      assert user.is_admin
    end

    test "update_admin/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Account.update_admin(user, @invalid_attrs)
      assert user == Account.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Account.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Account.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Account.change_user(user)
    end

    test "change_user_registration/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Account.change_user_registration(user)
    end

    test "change_admin_registration/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Account.change_admin_registration(user)
    end

    test "change_admin/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Account.change_admin(user)
    end
  end
end

defmodule DungeonCrawlWeb.EquipmentControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Equipment.Item

  @valid_attrs %{name: "ray gnu", description: "A device that shoots rays", script: "pew pew"}
  @update_attrs %{description: "updated"}
  @invalid_attrs %{name: ""}

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, equipment_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "registered users who are not admins" do
    setup [:normal_user]

    test "lists all entries on index", %{conn: conn} do
      items_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, equipment_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing items"
      assert html_response(conn, 200) =~ "My Item"
      refute html_response(conn, 200) =~ "Someone elses item"
      refute html_response(conn, 200) =~ "Unowned item"
    end

    test "renders form for new resources", %{conn: conn} do
      conn = get conn, equipment_path(conn, :new)
      assert html_response(conn, 200) =~ "New item"
    end

    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post conn, equipment_path(conn, :create), item: @valid_attrs
      assert redirected_to(conn) == equipment_path(conn, :index)
      new_item = Repo.get_by(Item, @valid_attrs)
      assert new_item
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, equipment_path(conn, :create), item: @invalid_attrs
      assert html_response(conn, 200) =~ "New item"
    end

    test "shows chosen resource", %{conn: conn} do
      target_item = insert_item(Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id))
      conn = get conn, equipment_path(conn, :show, target_item)
      assert html_response(conn, 200) =~ "Show item"
    end

    test "redirects if chosen resource is someone elses", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = get conn, equipment_path(conn, :show, target_item)
      assert redirected_to(conn) == equipment_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, equipment_path(conn, :show, -1)
      end
    end

    test "renders form for editing chosen resource", %{conn: conn} do
      target_item = insert_item(%{user_id: conn.assigns.current_user.id})
      conn = get conn, equipment_path(conn, :edit, target_item)
      assert html_response(conn, 200) =~ "Edit item"
    end

    test "redirects when trying to edit someone elses resource", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = get conn, equipment_path(conn, :edit, target_item)
      assert redirected_to(conn) == equipment_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "updates chosen resource and redirects when data is valid", %{conn: conn} do
      target_item = insert_item Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id)
      conn = put conn, equipment_path(conn, :update, target_item), item: @update_attrs
      assert redirected_to(conn) == equipment_path(conn, :show, target_item)
      assert Repo.get_by(Item, Map.merge(@valid_attrs,@update_attrs))
    end

    test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
      target_item = insert_item(%{user_id: conn.assigns.current_user.id})
      conn = put conn, equipment_path(conn, :update, target_item), item: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit item"
    end

    test "does not update if chosen resource belongs to someone else", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = put conn, equipment_path(conn, :update, target_item), item: @update_attrs
      assert redirected_to(conn) == equipment_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "deletes chosen resource on delete", %{conn: conn} do
      target_item = insert_item(%{user_id: conn.assigns.current_user.id})
      conn = delete conn, equipment_path(conn, :delete, target_item)
      assert redirected_to(conn) == equipment_path(conn, :index)
      refute Repo.get(Item, target_item.id)
    end
  end

  describe "admin users" do
    setup [:admin_user]

    test "lists all entries on index", %{conn: conn} do
      items_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, equipment_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing items"
      assert html_response(conn, 200) =~ "My Item"
      assert html_response(conn, 200) =~ "Someone elses item"
      assert html_response(conn, 200) =~ "Unowned item"
    end

    test "lists users entries on index", %{conn: conn} do
      items_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, equipment_path(conn, :index, %{list: "mine"})
      assert html_response(conn, 200) =~ "Listing items"
      assert html_response(conn, 200) =~ "My Item"
      refute html_response(conn, 200) =~ "Someone elses item"
      refute html_response(conn, 200) =~ "Unowned item"
    end

    test "lists unowned entries on index", %{conn: conn} do
      items_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, equipment_path(conn, :index, %{list: "nil"})
      assert html_response(conn, 200) =~ "Listing items"
      refute html_response(conn, 200) =~ "My Item"
      refute html_response(conn, 200) =~ "Someone elses item"
      assert html_response(conn, 200) =~ "Unowned item"
    end

    test "renders form for new resources", %{conn: conn} do
      conn = get conn, equipment_path(conn, :new)
      assert html_response(conn, 200) =~ "New item"
    end

    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post conn, equipment_path(conn, :create), item: @valid_attrs
      assert redirected_to(conn) == equipment_path(conn, :index)
      new_item = Repo.get_by(Item, @valid_attrs)
      assert new_item
      assert new_item.user_id == nil
    end

    test "creates resource and redirects when data is valid and can own", %{conn: conn} do
      conn = post conn, equipment_path(conn, :create), item: @valid_attrs, self_owned: "true"
      assert redirected_to(conn) == equipment_path(conn, :index)
      new_item = Repo.get_by(Item, @valid_attrs)
      assert new_item
      assert new_item.user_id == conn.assigns.current_user.id
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, equipment_path(conn, :create), item: @invalid_attrs
      assert html_response(conn, 200) =~ "New item"
    end

    test "shows chosen resource", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = get conn, equipment_path(conn, :show, target_item)
      assert html_response(conn, 200) =~ "Show item"
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, equipment_path(conn, :show, -1)
      end
    end

    test "renders form for editing chosen resource", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = get conn, equipment_path(conn, :edit, target_item)
      assert html_response(conn, 200) =~ "Edit item"
    end

   test "can edit active item", %{conn: conn} do
     item = insert_item(%{active: true})
     conn = get conn, equipment_path(conn, :edit, item), item: @update_attrs
     assert html_response(conn, 200) =~ "Edit item"
   end

    test "updates chosen resource and redirects when data is valid", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = put conn, equipment_path(conn, :update, target_item), item: @update_attrs, self_owned: "true"
      assert redirected_to(conn) == equipment_path(conn, :show, target_item)
      updated_item = Repo.get_by(Item, Map.merge(@valid_attrs,@update_attrs))
      assert updated_item
      assert updated_item.user_id == conn.assigns.current_user.id
    end

    test "updates chosen resource and redirects when data is valid and can assign to no one", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = put conn, equipment_path(conn, :update, target_item), item: @update_attrs, self_owned: "false"
      assert redirected_to(conn) == equipment_path(conn, :show, target_item)
      updated_item = Repo.get_by(Item, Map.merge(@valid_attrs,@update_attrs))
      assert updated_item
      assert updated_item.user_id == nil
    end

    test "updates chosen resource and redirects when data is valid and cannot assign to no one if owned by someone else", %{conn: conn} do
      other_user = insert_user()
      target_item = insert_item(Map.put(@valid_attrs, :user_id, other_user.id))
      conn = put conn, equipment_path(conn, :update, target_item), item: @update_attrs, self_owned: "false"
      assert redirected_to(conn) == equipment_path(conn, :show, target_item)
      updated_item = Repo.get_by(Item, Map.merge(@valid_attrs, @update_attrs))
      assert updated_item
      assert updated_item.user_id == other_user.id
    end

    test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = put conn, equipment_path(conn, :update, target_item), item: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit item"
    end

    test "deletes chosen resource on delete", %{conn: conn} do
      target_item = insert_item @valid_attrs
      conn = delete conn, equipment_path(conn, :delete, target_item)
      assert redirected_to(conn) == equipment_path(conn, :index)
      refute Repo.get(Item, target_item.id)
    end
  end

  defp normal_user(_) do
    user = insert_user(%{username: "Threepwood", is_admin: false})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  defp admin_user(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  defp items_with_one_of_each_ownership_type(user) do
    insert_item(%{name: "My Item", user_id: user.id})
    insert_item(%{name: "Someone elses item", user_id: insert_user().id})
    insert_item(%{name: "Unowned item", user_id: nil})
  end
end

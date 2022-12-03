defmodule DungeonCrawlWeb.Editor.TileTemplateControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.TileTemplates.TileTemplate

  @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "red", background_color: "black", group_name: "misc"}
  @update_attrs %{color: "puce", character: "█"}
  @invalid_attrs %{name: "", character: "BIG"}

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, tile_template_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "registered users who are not admins" do
    setup [:normal_user]

    test "lists all entries on index", %{conn: conn} do
      templates_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, tile_template_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing tile templates"
      assert html_response(conn, 200) =~ "My Template"
      refute html_response(conn, 200) =~ "Someone elses template"
      refute html_response(conn, 200) =~ "Unowned template"
    end

    test "renders form for new resources", %{conn: conn} do
      conn = get conn, tile_template_path(conn, :new)
      assert html_response(conn, 200) =~ "New tile template"
    end

    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post conn, tile_template_path(conn, :create), tile_template: @valid_attrs
      assert redirected_to(conn) == tile_template_path(conn, :index)
      new_tile_template = Repo.get_by(TileTemplate, Map.put(@valid_attrs, :group_name, "custom"))
      assert new_tile_template
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, tile_template_path(conn, :create), tile_template: @invalid_attrs
      assert html_response(conn, 200) =~ "New tile template"
    end

    test "shows chosen resource", %{conn: conn} do
      target_tile_template = insert_tile_template(Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id))
      conn = get conn, tile_template_path(conn, :show, target_tile_template)
      assert html_response(conn, 200) =~ "Show tile template"
    end

    test "redirects if chosen resource is someone elses", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = get conn, tile_template_path(conn, :show, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, tile_template_path(conn, :show, -1)
      end
    end

    test "renders form for editing chosen resource", %{conn: conn} do
      target_tile_template = insert_tile_template(%{user_id: conn.assigns.current_user.id})
      conn = get conn, tile_template_path(conn, :edit, target_tile_template)
      assert html_response(conn, 200) =~ "Edit tile template"
    end

    test "redirects when trying to edit someone elses resource", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = get conn, tile_template_path(conn, :edit, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "cannot edit active tile_template", %{conn: conn} do
      tile_template = insert_tile_template(%{active: true, user_id: conn.assigns.current_user.id})
      conn = get conn, tile_template_path(conn, :edit, tile_template), tile_template: @update_attrs
      assert redirected_to(conn) == tile_template_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit active tile template"
    end

    test "updates chosen resource and redirects when data is valid", %{conn: conn} do
      target_tile_template = insert_tile_template Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id)
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert Repo.get_by(TileTemplate, Map.merge(@valid_attrs,@update_attrs))
    end

    test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
      target_tile_template = insert_tile_template(%{user_id: conn.assigns.current_user.id})
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit tile template"
    end

    test "does not update if chosen resource belongs to someone else", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs
      assert redirected_to(conn) == tile_template_path(conn, :index)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "cannot update active tile template", %{conn: conn} do
      tile_template = insert_tile_template(%{active: true, user_id: conn.assigns.current_user.id})
      conn = put conn, tile_template_path(conn, :update, tile_template), tile_template: @update_attrs
      assert redirected_to(conn) == tile_template_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit active tile template"
    end

    test "soft deletes chosen resource on delete", %{conn: conn} do
      target_tile_template = insert_tile_template(%{user_id: conn.assigns.current_user.id})
      conn = delete conn, tile_template_path(conn, :delete, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :index)
      refute Repo.get!(TileTemplate, target_tile_template.id).deleted_at == nil
    end

    test "activtes chosen tile_template", %{conn: conn} do
      target_tile_template = insert_tile_template(Map.put(@valid_attrs, :user_id, conn.assigns.current_user.id))
      conn = put conn, tile_template_activate_path(conn, :activate, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert Repo.get!(TileTemplate, target_tile_template.id).active
    end

    test "soft deletes the previous version on activate", %{conn: conn} do
      tile_template = insert_tile_template(%{user_id: conn.assigns.current_user.id})
      new_tile_template = insert_tile_template(%{previous_version_id: tile_template.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, tile_template_activate_path(conn, :activate, new_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, new_tile_template)
      assert Repo.get!(TileTemplate, tile_template.id).deleted_at
      assert Repo.get!(TileTemplate, new_tile_template.id).active
    end

    test "does not create a new version if tile_template not active", %{conn: conn} do
      target_tile_template = insert_tile_template(%{user_id: conn.assigns.current_user.id})
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "Inactive tile template"
    end

    test "does not create a new version if tile_template already has a next version", %{conn: conn} do
      target_tile_template = insert_tile_template(%{active: true, user_id: conn.assigns.current_user.id})
      insert_tile_template(%{previous_version_id: target_tile_template.id})
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "New version already exists"
    end

    test "creates a new version", %{conn: conn} do
      target_tile_template = insert_tile_template(%{active: true, user_id: conn.assigns.current_user.id})
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      new_version = Repo.get_by!(TileTemplate, %{previous_version_id: target_tile_template.id})
      assert redirected_to(conn) == tile_template_path(conn, :show, new_version)
      refute Repo.get!(TileTemplate, target_tile_template.id).deleted_at
      refute Repo.get!(TileTemplate, new_version.id).active
    end
  end

  describe "admin users" do
    setup [:admin_user]

    test "lists all entries on index", %{conn: conn} do
      templates_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, tile_template_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing tile templates"
      assert html_response(conn, 200) =~ "My Template"
      assert html_response(conn, 200) =~ "Someone elses template"
      assert html_response(conn, 200) =~ "Unowned template"
    end

    test "lists users entries on index", %{conn: conn} do
      templates_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, tile_template_path(conn, :index, %{list: "mine"})
      assert html_response(conn, 200) =~ "Listing tile templates"
      assert html_response(conn, 200) =~ "My Template"
      refute html_response(conn, 200) =~ "Someone elses template"
      refute html_response(conn, 200) =~ "Unowned template"
    end

    test "lists unowned entries on index", %{conn: conn} do
      templates_with_one_of_each_ownership_type(conn.assigns.current_user)
      conn = get conn, tile_template_path(conn, :index, %{list: "nil"})
      assert html_response(conn, 200) =~ "Listing tile templates"
      refute html_response(conn, 200) =~ "My Template"
      refute html_response(conn, 200) =~ "Someone elses template"
      assert html_response(conn, 200) =~ "Unowned template"
    end

    test "renders form for new resources", %{conn: conn} do
      conn = get conn, tile_template_path(conn, :new)
      assert html_response(conn, 200) =~ "New tile template"
    end

    test "creates resource and redirects when data is valid", %{conn: conn} do
      conn = post conn, tile_template_path(conn, :create), tile_template: @valid_attrs
      assert redirected_to(conn) == tile_template_path(conn, :index)
      new_tile_template = Repo.get_by(TileTemplate, @valid_attrs)
      assert new_tile_template
      assert new_tile_template.user_id == nil
      # admin can assign group_name
      assert new_tile_template.group_name == "misc"
    end

    test "creates resource and redirects when data is valid and can own", %{conn: conn} do
      conn = post conn, tile_template_path(conn, :create), tile_template: @valid_attrs, self_owned: "true"
      assert redirected_to(conn) == tile_template_path(conn, :index)
      new_tile_template = Repo.get_by(TileTemplate, @valid_attrs)
      assert new_tile_template
      assert new_tile_template.user_id == conn.assigns.current_user.id
    end

    test "does not create resource and renders errors when data is invalid", %{conn: conn} do
      conn = post conn, tile_template_path(conn, :create), tile_template: @invalid_attrs
      assert html_response(conn, 200) =~ "New tile template"
    end

    test "shows chosen resource", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = get conn, tile_template_path(conn, :show, target_tile_template)
      assert html_response(conn, 200) =~ "Show tile template"
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, tile_template_path(conn, :show, -1)
      end
    end

    test "renders form for editing chosen resource", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = get conn, tile_template_path(conn, :edit, target_tile_template)
      assert html_response(conn, 200) =~ "Edit tile template"
    end

   test "can edit active tile_template", %{conn: conn} do
     tile_template = insert_tile_template(%{active: true})
     conn = get conn, tile_template_path(conn, :edit, tile_template), tile_template: @update_attrs
     assert html_response(conn, 200) =~ "Edit tile template"
   end

    test "updates chosen resource and redirects when data is valid", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs, self_owned: "true"
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      updated_tile_template = Repo.get_by(TileTemplate, Map.merge(@valid_attrs,@update_attrs))
      assert updated_tile_template
      assert updated_tile_template.user_id == conn.assigns.current_user.id
    end

    test "updates chosen resource and redirects when data is valid and can assign to no one", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs, self_owned: "false"
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      updated_tile_template = Repo.get_by(TileTemplate, Map.merge(@valid_attrs,@update_attrs))
      assert updated_tile_template
      assert updated_tile_template.user_id == nil
    end

    test "updates chosen resource and redirects when data is valid and cannot assign to no one if owned by someone else", %{conn: conn} do
      other_user = insert_user()
      target_tile_template = insert_tile_template(Map.put(@valid_attrs, :user_id, other_user.id))
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs, self_owned: "false"
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      updated_tile_template = Repo.get_by(TileTemplate, Map.merge(@valid_attrs, @update_attrs))
      assert updated_tile_template
      assert updated_tile_template.user_id == other_user.id
    end

    test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit tile template"
    end

    test "can update active tile template", %{conn: conn} do
      target_tile_template = insert_tile_template(Map.put(@valid_attrs, :active, true))
      conn = put conn, tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert Repo.get_by(TileTemplate, Map.merge(@valid_attrs, @update_attrs))
    end

    test "soft deletes chosen resource on delete", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = delete conn, tile_template_path(conn, :delete, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :index)
      refute Repo.get!(TileTemplate, target_tile_template.id).deleted_at == nil
    end

    test "activtes chosen tile_template", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = put conn, tile_template_activate_path(conn, :activate, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert Repo.get!(TileTemplate, target_tile_template.id).active
    end

    test "soft deletes the previous version on activate", %{conn: conn} do
      tile_template = insert_tile_template @valid_attrs
      new_tile_template = insert_tile_template(%{previous_version_id: tile_template.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, tile_template_activate_path(conn, :activate, new_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, new_tile_template)
      assert Repo.get!(TileTemplate, tile_template.id).deleted_at
      assert Repo.get!(TileTemplate, new_tile_template.id).active
    end

    test "does not create a new version if tile_template not active", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "Inactive tile template"
    end

    test "does not create a new version if tile_template already has a next version", %{conn: conn} do
      target_tile_template = insert_tile_template Map.merge(@valid_attrs, %{active: true})
      insert_tile_template(%{previous_version_id: target_tile_template.id})
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "New version already exists"
    end

    test "does not create a new version if tile_template is corrupted", %{conn: conn} do
      target_tile_template = insert_tile_template Map.merge(@valid_attrs, %{active: true})

      {:ok, target_tile_template} = Repo.update(Ecto.Changeset.cast(target_tile_template, %{script: "#BECOME color: #corrupt"}, [:script]))
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "Error creating new version."
    end

    test "creates a new version", %{conn: conn} do
      target_tile_template = insert_tile_template Map.merge(@valid_attrs, %{active: true})
      conn = post conn, tile_template_new_version_path(conn, :new_version, target_tile_template)
      new_version = Repo.get_by!(TileTemplate, %{previous_version_id: target_tile_template.id})
      assert redirected_to(conn) == tile_template_path(conn, :show, new_version)
      refute Repo.get!(TileTemplate, target_tile_template.id).deleted_at
      refute Repo.get!(TileTemplate, new_version.id).active
    end
  end


  
#  defp create_tile_template(opts) do
#    tile_template = insert_tile_template(%{user_id: opts.conn.assigns[:current_user].id})
#    {:ok, conn: opts.conn, tile_template: tile_template}
#  end

#  defp create_admin_user(_) do
#    user = insert_user(%{username: "CSwaggins", is_admin: true})
#    conn = assign(build_conn(), :current_user, user)
#    {:ok, conn: conn, user: user}
#  end


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

  defp templates_with_one_of_each_ownership_type(user) do
    insert_tile_template(%{name: "My Template", user_id: user.id})
    insert_tile_template(%{name: "Someone elses template", user_id: insert_user().id})
    insert_tile_template(%{name: "Unowned template", user_id: nil})
  end
end

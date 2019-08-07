defmodule DungeonCrawlWeb.ManageTileTemplateControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  @valid_attrs %{name: "A Big X", description: "A big capital X", character: "X", color: "red", background_color: "black"}
  @update_attrs %{color: "puce", character: "█"}
  @invalid_attrs %{name: "", character: "BIG"}

  setup config do
    user = insert_user(%{username: "maxheadroom", is_admin: !config[:not_admin]})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  @tag not_admin: true
  test "redirects non admin users", %{conn: conn} do
    conn = get conn, manage_tile_template_path(conn, :index)
    assert redirected_to(conn) == page_path(conn, :index)
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, manage_tile_template_path(conn, :index)
    assert html_response(conn, 200) =~ "Listing tile templates"
  end

  test "renders form for new resources", %{conn: conn} do
    conn = get conn, manage_tile_template_path(conn, :new)
    assert html_response(conn, 200) =~ "New tile template"
  end

  test "creates resource and redirects when data is valid", %{conn: conn} do
    conn = post conn, manage_tile_template_path(conn, :create), tile_template: @valid_attrs
    assert redirected_to(conn) == manage_tile_template_path(conn, :index)
    new_tile_template = Repo.get_by(TileTemplate, @valid_attrs)
    assert new_tile_template
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, manage_tile_template_path(conn, :create), tile_template: @invalid_attrs
    assert html_response(conn, 200) =~ "New tile template"
  end

  test "shows chosen resource", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = get conn, manage_tile_template_path(conn, :show, target_tile_template)
    assert html_response(conn, 200) =~ "Show tile template"
  end

  test "renders page not found when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, manage_tile_template_path(conn, :show, -1)
    end
  end

  test "renders form for editing chosen resource", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = get conn, manage_tile_template_path(conn, :edit, target_tile_template)
    assert html_response(conn, 200) =~ "Edit tile template"
  end

  test "updates chosen resource and redirects when data is valid", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = put conn, manage_tile_template_path(conn, :update, target_tile_template), tile_template: @update_attrs
    assert redirected_to(conn) == manage_tile_template_path(conn, :show, target_tile_template)
    assert Repo.get_by(TileTemplate, Map.merge(@valid_attrs,@update_attrs))
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = put conn, manage_tile_template_path(conn, :update, target_tile_template), tile_template: @invalid_attrs
    assert html_response(conn, 200) =~ "Edit tile template"
  end

  test "soft deletes chosen resource", %{conn: conn} do
    target_tile_template = insert_tile_template @valid_attrs
    conn = delete conn, manage_tile_template_path(conn, :delete, target_tile_template)
    assert redirected_to(conn) == manage_tile_template_path(conn, :index)
    refute Repo.get!(TileTemplate, target_tile_template.id).deleted_at == nil
  end


  describe "activate tile_template" do
#    setup [:create_admin_user, :create_tile_template]

    test "activtes chosen tile_template", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = put conn, manage_tile_template_activate_path(conn, :activate, target_tile_template)
      assert redirected_to(conn) == manage_tile_template_path(conn, :show, target_tile_template)
      assert Repo.get!(TileTemplate, target_tile_template.id).active
    end

    test "soft deletes the previous version", %{conn: conn} do
      tile_template = insert_tile_template @valid_attrs
      new_tile_template = insert_tile_template(%{previous_version_id: tile_template.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, manage_tile_template_activate_path(conn, :activate, new_tile_template)
      assert redirected_to(conn) == manage_tile_template_path(conn, :show, new_tile_template)
      assert Repo.get!(TileTemplate, tile_template.id).deleted_at
      assert Repo.get!(TileTemplate, new_tile_template.id).active
    end
  end

  describe "new_version tile_template" do
#    setup [:create_admin_user, :create_tile_template]

    test "does not create a new version if tile_template not active", %{conn: conn} do
      target_tile_template = insert_tile_template @valid_attrs
      conn = post conn, manage_tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == manage_tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "Inactive tile template"
    end

    test "does not create a new version if tile_template already has a next version", %{conn: conn} do
      target_tile_template = insert_tile_template Map.merge(@valid_attrs, %{active: true})
      insert_tile_template(%{previous_version_id: target_tile_template.id})
      conn = post conn, manage_tile_template_new_version_path(conn, :new_version, target_tile_template)
      assert redirected_to(conn) == manage_tile_template_path(conn, :show, target_tile_template)
      assert get_flash(conn, :error) == "New version already exists"
    end

    test "creates a new version", %{conn: conn} do
      target_tile_template = insert_tile_template Map.merge(@valid_attrs, %{active: true})
      conn = post conn, manage_tile_template_new_version_path(conn, :new_version, target_tile_template)
      new_version = Repo.get_by!(TileTemplate, %{previous_version_id: target_tile_template.id})
      assert redirected_to(conn) == manage_tile_template_path(conn, :show, new_version)
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
end

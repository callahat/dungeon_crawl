defmodule DungeonCrawlWeb.Admin.SettingControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  @update_attrs %{autogen_solo_enabled: false, max_height: 77, max_instances: 43, max_width: 111, non_admin_dungeons_enabled: false}
  @invalid_attrs %{max_height: 9008, max_width: 10}

  setup %{conn: conn} = config do
    if username = config[:login_as] do
      user = insert_user(%{username: username, is_admin: !config[:not_admin]})
      conn = assign(build_conn(), :current_user, user)
      {:ok, conn: conn, user: user}
    else
      {:ok, conn: conn}
    end
  end

  @tag login_as: "notadmin", not_admin: true
  test "redirects non admin users", %{conn: conn} do
    conn = get conn, admin_setting_path(conn, :edit)
    assert redirected_to(conn) == page_path(conn, :index)
  end

  test "redirects non logged in users", %{conn: conn} do
    conn = get conn, admin_setting_path(conn, :edit)
    assert redirected_to(conn) == page_path(conn, :index)
  end

  describe "edit setting" do
    @tag login_as: "maxheadroom"
    test "renders form for editing chosen setting", %{conn: conn} do
      conn = get(conn, admin_setting_path(conn, :edit))
      assert html_response(conn, 200) =~ "Edit Setting"
    end
  end

  describe "update setting" do
    @tag login_as: "maxheadroom"
    test "redirects when data is valid", %{conn: conn} do
      conn = put(conn, admin_setting_path(conn, :update), setting: @update_attrs)
      assert redirected_to(conn) == admin_setting_path(conn, :edit)
    end

    @tag login_as: "maxheadroom"
    test "renders form for editing chosen setting", %{conn: conn} do
      conn = get(conn, admin_setting_path(conn, :edit))
      assert html_response(conn, 200) =~ "Edit Setting"
    end

    @tag login_as: "maxheadroom"
    test "renders errors when data is invalid", %{conn: conn} do
      conn = put(conn, admin_setting_path(conn, :update), setting: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Setting"
    end
  end
end

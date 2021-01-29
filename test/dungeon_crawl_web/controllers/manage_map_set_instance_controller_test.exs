defmodule DungeonCrawlWeb.ManageMapSetInstanceControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.MapSetRegistry

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, manage_map_set_instance_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "registered user but not admin" do
    setup [:normal_user]

    test "redirects non admin users", %{conn: conn} do
      conn = get conn, manage_map_set_instance_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "with an admin user" do
    setup [:admin_user]

    test "lists all entries on index", %{conn: conn} do
      setup_map_set_instance()
      conn = get conn, manage_map_set_instance_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing map set instances"
    end

    test "shows chosen map set instance", %{conn: conn} do
      instance = setup_map_set_instance()
      conn = get conn, manage_map_set_instance_path(conn, :show, instance.id)
      assert html_response(conn, 200) =~ "DB Backed Map Set Process"
    end

    test "shows chosen map set instance when no backing db instance", %{conn: conn} do
      instance = setup_map_set_instance()
      DungeonInstances.delete_map_set(instance)
      conn = get conn, manage_map_set_instance_path(conn, :show, instance.id)
      assert html_response(conn, 200) =~ "Orphaned Map Set Process"
    end

    test "redirects with a message when map set instance is nonexistent", %{conn: conn} do
      setup_map_set_instance()
      conn = get conn, manage_map_set_instance_path(conn, :show, -1)
      assert redirected_to(conn) == manage_map_set_instance_path(conn, :index)
      assert get_flash(conn, :info) == "Instance not found: `-1`"
    end

    test "deletes chosen map set instance", %{conn: conn} do
      instance = setup_map_set_instance()
      conn = delete conn, manage_map_set_instance_path(conn, :delete, instance.id)
      assert redirected_to(conn) == manage_map_set_instance_path(conn, :index)
      :timer.sleep 50
      assert DungeonInstances.get_map_set(instance.id)
      assert :error = MapSetRegistry.lookup(MapSetInstanceRegistry, instance.id)
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

  defp setup_map_set_instance() do
    msi = insert_autogenerated_map_set_instance()
    MapSetRegistry.create(MapSetInstanceRegistry, msi.id)
    msi
  end
end

defmodule DungeonCrawlWeb.ManageDungeonInstanceControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry
  alias DungeonCrawl.DungeonProcesses.Registrar
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, manage_dungeon_instance_path(conn, :show, 1, 1)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "registered user but not admin" do
    setup [:normal_user]

    test "redirects non admin users", %{conn: conn} do
      conn = get conn, manage_dungeon_instance_path(conn, :show, 1, 1)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "with an admin user" do
    setup [:admin_user]

    test "shows chosen instance", %{conn: conn} do
      instance = setup_level_instance()
      conn = get conn, manage_dungeon_instance_path(conn, :show, instance.dungeon_instance_id, instance.id)
      assert html_response(conn, 200) =~ "DB Backed Instance Process"
    end

    test "shows chosen instance when no backing db instance", %{conn: conn} do
      instance = setup_level_instance()
      {:ok, instance_registry} = Registrar.instance_registry(instance.dungeon_instance_id)
      InstanceRegistry.create(instance_registry, 1, [], [], %{rows: 0, cols: 0}, instance.dungeon_instance_id)
      conn = get conn, manage_dungeon_instance_path(conn, :show, instance.dungeon_instance_id, 1)
      assert html_response(conn, 200) =~ "Orphaned Instance Process"
    end

    test "redirects with a message when instance is nonexistent", %{conn: conn} do
      instance = setup_level_instance()
      conn = get conn, manage_dungeon_instance_path(conn, :show, instance.dungeon_instance_id, -1)
      assert redirected_to(conn) == manage_map_set_instance_path(conn, :show, instance.dungeon_instance_id)
      assert get_flash(conn, :info) == "Instance not found: `-1`"
    end

    test "deletes chosen instance", %{conn: conn} do
      instance = setup_level_instance()
      {:ok, instance_registry} = Registrar.instance_registry(instance.dungeon_instance_id)
      conn = delete conn, manage_dungeon_instance_path(conn, :delete, instance.dungeon_instance_id, instance.id)
      assert redirected_to(conn) == manage_map_set_instance_path(conn, :show, instance.dungeon_instance_id)
      :timer.sleep 50
      assert DungeonInstances.get_level(instance.id)
      assert :error = InstanceRegistry.lookup(instance_registry, instance.id)
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

  defp setup_level_instance() do
    level_instance = insert_autogenerated_level_instance()
    DungeonRegistry.create(DungeonInstanceRegistry, level_instance.dungeon_instance_id)
    level_instance
  end
end

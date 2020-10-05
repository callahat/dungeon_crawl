defmodule DungeonCrawlWeb.ManageDungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, manage_dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "registered user but not admin" do
    setup [:normal_user]

    test "redirects non admin users", %{conn: conn} do
      conn = get conn, manage_dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "with an admin user" do
    setup [:admin_user]

    test "lists all entries on index", %{conn: conn} do
      insert_autogenerated_map_set()
      insert_autogenerated_map_set_instance()
      conn = get conn, manage_dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end

    test "lists all soft deleted entries on index", %{conn: conn} do
      conn = get conn, manage_dungeon_path(conn, :index, show_deleted: "true")
      assert html_response(conn, 200) =~ "Listing soft deleted dungeons"
    end

    test "shows chosen resource", %{conn: conn} do
      map_set = insert_autogenerated_map_set()
      conn = get conn, manage_dungeon_path(conn, :show, map_set)
      assert html_response(conn, 200) =~ "Dungeon: "
    end

    test "shows chosen resource with instance", %{conn: conn} do
      msi = Repo.preload insert_autogenerated_map_set_instance(), :map_set
      conn = get conn, manage_dungeon_path(conn, :show, msi.map_set, instance_id: msi.id)
      assert html_response(conn, 200) =~ "Dungeon: "
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, manage_dungeon_path(conn, :show, -1)
      end
    end

    test "deletes chosen instance", %{conn: conn} do
      msi = insert_autogenerated_map_set_instance()
      map_set = Repo.preload(msi, :map_set).map_set
      conn = delete conn, manage_dungeon_path(conn, :delete, map_set, instance_id: msi.id)
      assert redirected_to(conn) == manage_dungeon_path(conn, :show, map_set)
      assert Dungeon.get_map_set(map_set.id)
      refute Dungeon.get_map_set(map_set.id).deleted_at
      refute DungeonInstances.get_map_set(msi.id)
    end

    test "deletes chosen resource", %{conn: conn} do
      map_set = insert_autogenerated_map_set()
      conn = delete conn, manage_dungeon_path(conn, :delete, map_set)
      assert redirected_to(conn) == manage_dungeon_path(conn, :index)
      assert Dungeon.get_map_set(map_set.id)
      assert Dungeon.get_map_set(map_set.id).deleted_at
    end

    test "hard deletes chosen resource", %{conn: conn} do
      map_set = insert_autogenerated_map_set()
      conn = delete conn, manage_dungeon_path(conn, :delete, map_set, hard_delete: "true")
      assert redirected_to(conn) == manage_dungeon_path(conn, :index, show_deleted: "true")
      refute Dungeon.get_map(map_set.id)
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
end

defmodule DungeonCrawlWeb.Admin.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Games

  import DungeonCrawl.GamesFixtures

  describe "non registered users" do
    test "redirects non admin users", %{conn: conn} do
      conn = get conn, admin_dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "registered user but not admin" do
    setup [:normal_user]

    test "redirects non admin users", %{conn: conn} do
      conn = get conn, admin_dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
    # overkill to hit the other methods
  end

  describe "with an admin user" do
    setup [:admin_user]

    test "lists all entries on index", %{conn: conn} do
      insert_autogenerated_dungeon()
      insert_autogenerated_dungeon_instance()
      conn = get conn, admin_dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end

    test "lists all soft deleted entries on index", %{conn: conn} do
      insert_autogenerated_dungeon(%{deleted_at: NaiveDateTime.local_now()})
      conn = get conn, admin_dungeon_path(conn, :index, show_deleted: "true")
      assert html_response(conn, 200) =~ "Listing soft deleted dungeons"
    end

    test "shows chosen resource", %{conn: conn} do
      dungeon = insert_autogenerated_dungeon()
      conn = get conn, admin_dungeon_path(conn, :show, dungeon)
      assert html_response(conn, 200) =~ "Dungeon: "
    end

    test "shows chosen resource when it has instances that arent selected", %{conn: conn} do
      instance = Repo.preload(insert_autogenerated_dungeon_instance(), :levels)
      save_fixture(%{level_instance_id: Enum.at(instance.levels, 0).id})
      conn = get conn, admin_dungeon_path(conn, :show, instance.dungeon_id)
      assert html_response(conn, 200) =~ "Dungeon: "
    end

    test "shows chosen resource with instance", %{conn: conn} do
      level_instance = insert_autogenerated_level_instance()
      save_fixture(%{level_instance_id: level_instance.id})
      dungeon_instance = Repo.preload(level_instance, [dungeon: :dungeon]).dungeon
      dungeon = dungeon_instance.dungeon
      updated_conn = get conn, admin_dungeon_path(conn, :show, dungeon, instance_id: dungeon_instance.id)
      assert html_response(updated_conn, 200) =~ "Dungeon: "
      assert html_response(updated_conn, 200) =~ "Saved Games"
      updated_conn = get conn, admin_dungeon_path(conn, :show, dungeon, instance_id: dungeon_instance.id, level: "#{level_instance.number}")
      assert html_response(updated_conn, 200) =~ "Dungeon: "
    end

    test "renders page not found when id is nonexistent", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, admin_dungeon_path(conn, :show, -1)
      end
    end

    test "deletes chosen save", %{conn: conn} do
      level_instance = insert_autogenerated_level_instance()
      save = save_fixture(%{user_id_hash: "asdf", level_instance_id: level_instance.id})
      dungeon_instance = Repo.preload(level_instance, [dungeon: :dungeon]).dungeon
      dungeon = dungeon_instance.dungeon
      conn = delete conn, admin_dungeon_path(conn, :delete, dungeon, instance_id: dungeon_instance.id, save_id: save.id)

      assert redirected_to(conn) == admin_dungeon_path(conn, :show, dungeon, instance_id: dungeon_instance.id)
      assert Dungeons.get_dungeon(dungeon.id)
      assert DungeonInstances.get_dungeon(dungeon_instance.id)
      refute Games.get_save(save.id)
    end

    test "deletes chosen instance", %{conn: conn} do
      dungeon_instance = insert_autogenerated_dungeon_instance()
      dungeon = Repo.preload(dungeon_instance, :dungeon).dungeon
      conn = delete conn, admin_dungeon_path(conn, :delete, dungeon, instance_id: dungeon_instance.id)
      assert redirected_to(conn) == admin_dungeon_path(conn, :show, dungeon)
      assert Dungeons.get_dungeon(dungeon.id)
      refute Dungeons.get_dungeon(dungeon.id).deleted_at
      refute DungeonInstances.get_dungeon(dungeon_instance.id)
    end

    test "deletes chosen dungeon", %{conn: conn} do
      dungeon = insert_autogenerated_dungeon()
      conn = delete conn, admin_dungeon_path(conn, :delete, dungeon)
      assert redirected_to(conn) == admin_dungeon_path(conn, :index)
      assert Dungeons.get_dungeon(dungeon.id)
      assert Dungeons.get_dungeon(dungeon.id).deleted_at
    end

    test "hard deletes chosen dungeon", %{conn: conn} do
      dungeon = insert_autogenerated_dungeon()
      conn = delete conn, admin_dungeon_path(conn, :delete, dungeon, hard_delete: "true")
      assert redirected_to(conn) == admin_dungeon_path(conn, :index, show_deleted: "true")
      refute Dungeons.get_dungeon(dungeon.id)
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

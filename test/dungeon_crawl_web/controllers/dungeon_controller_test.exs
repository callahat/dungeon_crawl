defmodule DungeonCrawlWeb.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Dungeon
  @create_attrs %{name: "some name", height: 40, width: 80}
  @update_attrs %{name: "new name", height: 40, width: 40}
  @invalid_attrs %{}

  def fixture(:dungeon) do
    {:ok, dungeon} = Dungeon.create_dungeon(@create_attrs)
    dungeon
  end

  describe "without a registered user" do
    describe "index" do
      test "redirects", %{conn: conn} do
        conn = get conn, dungeon_path(conn, :index)
        assert redirected_to(conn) == page_path(conn, :index)
      end
    end

    describe "new dungeon" do
      test "redirects", %{conn: conn} do
        conn = get conn, dungeon_path(conn, :new)
        assert redirected_to(conn) == page_path(conn, :index)
      end
    end

    describe "create dungeon" do
      test "redirects", %{conn: conn} do
        conn = post conn, dungeon_path(conn, :create), dungeon: @create_attrs
        assert redirected_to(conn) == page_path(conn, :index)
      end
    end

    describe "edit dungeon" do
      setup [:create_dungeon]

      test "redirects", %{conn: conn, dungeon: dungeon} do
        conn = get conn, dungeon_path(conn, :edit, dungeon)
        assert redirected_to(conn) == page_path(conn, :index)
      end
    end

    describe "update dungeon" do
      setup [:create_dungeon]

      test "redirects", %{conn: conn, dungeon: dungeon} do
        conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
        assert redirected_to(conn) == page_path(conn, :index)
      end
    end

    describe "delete dungeon" do
      setup [:create_dungeon]

      test "redirects", %{conn: conn, dungeon: dungeon} do
        conn = delete conn, dungeon_path(conn, :delete, dungeon)
        assert redirected_to(conn) == page_path(conn, :index)
      end
    end
  end

  describe "with a registered user" do
    setup [:create_user]

    describe "index" do
      test "lists all dungeons", %{conn: conn} do
        conn = get conn, dungeon_path(conn, :index)
        assert html_response(conn, 200) =~ "Listing Dungeons"
      end
    end

    describe "new dungeon" do
      test "renders form", %{conn: conn} do
        conn = get conn, dungeon_path(conn, :new)
        assert html_response(conn, 200) =~ "New Dungeon"
      end
    end

    describe "create dungeon" do
      test "redirects to show when data is valid", %{conn: conn} do
        conn = post conn, dungeon_path(conn, :create), dungeon: @create_attrs

        assert %{id: id} = redirected_params(conn)
        assert redirected_to(conn) == dungeon_path(conn, :show, id)

        conn = get conn, dungeon_path(conn, :show, id)
        assert html_response(conn, 200) =~ "Show Dungeon"
      end

      test "renders errors when data is invalid", %{conn: conn} do
        conn = post conn, dungeon_path(conn, :create), dungeon: @invalid_attrs
        assert html_response(conn, 200) =~ "New Dungeon"
      end
    end

    describe "edit dungeon" do
      setup [:create_dungeon]

      test "renders form for editing chosen dungeon", %{conn: conn, dungeon: dungeon} do
        conn = get conn, dungeon_path(conn, :edit, dungeon)
        assert html_response(conn, 200) =~ "Edit Dungeon"
      end
    end

    describe "update dungeon" do
      setup [:create_dungeon]

      test "redirects when data is valid", %{conn: conn, dungeon: dungeon} do
        conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
        assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)

        conn = get conn, dungeon_path(conn, :show, dungeon)
        assert html_response(conn, 200)
      end

      test "renders errors when data is invalid", %{conn: conn, dungeon: dungeon} do
        conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @invalid_attrs
        assert html_response(conn, 200) =~ "Edit Dungeon"
      end
    end

    describe "delete dungeon" do
      setup [:create_dungeon]

      test "deletes chosen dungeon", %{conn: conn, dungeon: dungeon} do
        conn = delete conn, dungeon_path(conn, :delete, dungeon)
        assert redirected_to(conn) == dungeon_path(conn, :index)
        assert_error_sent 404, fn ->
          get conn, dungeon_path(conn, :show, dungeon)
        end
      end
    end
  end

  defp create_dungeon(_) do
    dungeon = fixture(:dungeon)
    {:ok, dungeon: dungeon}
  end

  defp create_user() do
    user = insert_user(%{username: "CSwaggins"})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end
end

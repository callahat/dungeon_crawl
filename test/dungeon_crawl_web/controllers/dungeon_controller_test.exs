defmodule DungeonCrawlWeb.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Dungeon
  @create_attrs %{name: "some name", height: 40, width: 80}
  @update_attrs %{name: "new name", height: 40, width: 40}
  @invalid_attrs %{name: ""}

  def fixture(:dungeon, user_id) do
    {:ok, dungeon} = Dungeon.create_map(Map.put(@create_attrs, :user_id, user_id))
    dungeon
  end

  # Without registered user
  describe "index without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "new dungeon without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :new)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "create dungeon without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, dungeon_path(conn, :create), map: @create_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "edit dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_path(conn, :edit, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "update dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_path(conn, :update, dungeon), map: @update_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "delete dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, dungeon_path(conn, :delete, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end
  # /Without registered user

  # With a registered user
  describe "index with a registered user" do
    setup [:create_user]

    test "lists all dungeons", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end
  end

  describe "new dungeon with a registered user" do
    setup [:create_user]

    test "renders form", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :new)
      assert html_response(conn, 200) =~ "New dungeon"
    end
  end

  describe "create dungeon with a registered user" do
    setup [:create_user]

    test "redirects to show when data is valid", %{conn: conn} do
      conn = post conn, dungeon_path(conn, :create), map: @create_attrs

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == dungeon_path(conn, :show, id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, dungeon_path(conn, :create), map: @invalid_attrs
      assert html_response(conn, 200) =~ "New dungeon"
    end
  end

  describe "edit dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "renders form for editing chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_path(conn, :edit, dungeon)
      assert html_response(conn, 200) =~ "Edit dungeon"
    end
  end

  describe "update dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "redirects when data is valid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_path(conn, :update, dungeon), map: Elixir.Map.put(@update_attrs, :tile_changes, "[{\"row\": 1, \"col\": 1, \"tile_template_id\": 1}]")
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
    end

    test "renders errors when data is invalid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_path(conn, :update, dungeon), map: @invalid_attrs, tile_changes: []
      assert html_response(conn, 200) =~ "Edit dungeon"
    end
  end

  describe "delete dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "soft deletes chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, dungeon_path(conn, :delete, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      refute Repo.get!(Dungeon.Map, dungeon.id).deleted_at == nil
    end
  end
  # /With a registered user

  defp create_dungeon(opts) do
    dungeon = fixture(:dungeon, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, dungeon: dungeon}
  end

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end
end

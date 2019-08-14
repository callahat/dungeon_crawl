defmodule DungeonCrawlWeb.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Player
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

  describe "show without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_path(conn, :show, dungeon)
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

  describe "show with a registered user" do
    setup [:create_user, :create_dungeon]

    test "renders show", %{conn: conn, dungeon: dungeon} do
      conn = get conn, dungeon_path(conn, :show, dungeon)
      assert html_response(conn, 200) =~ dungeon.name
    end
  end

  describe "show with a registered user but dungeon belongs to someone else" do
    setup [:create_user, :create_dungeon]

    test "renders show", %{conn: conn} do
      dungeon = fixture(:dungeon, insert_user(%{username: "Omer"}).id)
      conn = get conn, dungeon_path(conn, :show, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
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

    test "cannot edit active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeon.update_map(dungeon, %{active: true})
      conn = get conn, dungeon_path(conn, :edit, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
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

    test "cannot update active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeon.update_map(dungeon, %{active: true})
      conn = put conn, dungeon_path(conn, :update, dungeon), map: @update_attrs, tile_changes: []
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
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

  describe "activate dungeon" do
    setup [:create_user, :create_dungeon]

    test "activtes chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_activate_path(conn, :activate, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert Repo.get!(Dungeon.Map, dungeon.id).active
    end

    test "problem activating chosen dungeon", %{conn: conn, dungeon: dungeon} do
      inactive_tile_template = insert_tile_template(%{name: "INT", active: false})
      Repo.insert_all(Dungeon.MapTile, [%{dungeon_id: dungeon.id, row: 1, col: 1, tile_template_id: inactive_tile_template.id, z_index: 0}] )
      conn = put conn, dungeon_activate_path(conn, :activate, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert get_flash(conn, :error) == "Inactive tiles: INT (id: #{inactive_tile_template.id}) 1 times"
    end

    test "soft deletes the previous version", %{conn: conn, dungeon: dungeon} do
      new_map = insert_stubbed_dungeon(%{previous_version_id: dungeon.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, dungeon_activate_path(conn, :activate, new_map)
      assert redirected_to(conn) == dungeon_path(conn, :show, new_map)
      assert Repo.get!(Dungeon.Map, dungeon.id).deleted_at
      assert Repo.get!(Dungeon.Map, new_map.id).active
    end
  end

  describe "new_version dungeon" do
    setup [:create_user, :create_dungeon]

    test "does not create a new version if dungeon not active", %{conn: conn, dungeon: dungeon} do
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert get_flash(conn, :error) == "Inactive map"
    end

    test "does not create a new version if dungeon already has a next version", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeon.update_map(dungeon, %{active: true})
      _new_map = insert_stubbed_dungeon(%{previous_version_id: dungeon.id, user_id: conn.assigns[:current_user].id})
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert get_flash(conn, :error) == "New version already exists"
    end

    test "creates a new version", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeon.update_map(dungeon, %{active: true})
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      new_version = Dungeon.get_map_by(%{previous_version_id: dungeon.id})
      assert redirected_to(conn) == dungeon_path(conn, :show, new_version)
      refute Repo.get!(Dungeon.Map, dungeon.id).deleted_at
      refute Repo.get!(Dungeon.Map, new_version.id).active
    end
  end

  describe "test_crawl dungeon" do
    setup [:create_user]

    test "creates an instance", %{conn: conn, user: user} do
      dungeon = insert_autogenerated_dungeon(%{active: false, user_id: user.id})

      conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, dungeon)
      assert redirected_to(conn) == crawler_path(conn, :show)
      location = Player.get_location(user.user_id_hash)
      assert Player.get_dungeon(location) == dungeon
    end

    test "clears the players previous location if applicable", %{conn: conn, user: user} do
      dungeon = insert_autogenerated_dungeon(%{active: false, user_id: user.id})

      instance = insert_autogenerated_dungeon_instance(%{active: true})
      location = insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})

      _conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, dungeon)

      refute Repo.get(DungeonCrawl.Player.Location, location.id)
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

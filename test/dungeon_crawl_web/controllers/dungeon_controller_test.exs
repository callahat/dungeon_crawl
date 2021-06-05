defmodule DungeonCrawlWeb.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.{MapSet, MapTile}
  alias DungeonCrawl.Player
  @create_attrs %{name: "some name"}
  @update_attrs %{name: "new name"}
  @invalid_attrs %{name: ""}

  def fixture(:map_set, user_id) do
    {:ok, map_set} = Dungeons.create_map_set(Map.put(@create_attrs, :user_id, user_id))
    map_set
  end

  # Without registered user
  describe "index without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "show without a registered user" do
    setup [:create_map_set]

    test "redirects", %{conn: conn, map_set: map_set} do
      conn = get conn, dungeon_path(conn, :show, map_set)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "new map set without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :new)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "create map set without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, dungeon_path(conn, :create), map_set: @create_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "edit map_set without a registered user" do
    setup [:create_map_set]

    test "redirects", %{conn: conn, map_set: map_set} do
      conn = get conn, dungeon_path(conn, :edit, map_set)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "update map_set without a registered user" do
    setup [:create_map_set]

    test "redirects", %{conn: conn, map_set: map_set} do
      conn = put conn, dungeon_path(conn, :update, map_set), map_set: @update_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "delete map_set without a registered user" do
    setup [:create_map_set]

    test "redirects", %{conn: conn, map_set: map_set} do
      conn = delete conn, dungeon_path(conn, :delete, map_set)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end
  # /Without registered user

  describe "with a registered user but edit dungeons is disabled" do
    setup [:create_user]

    test "lists all map set", %{conn: conn} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, dungeon_path(conn, :index)
      assert redirected_to(conn) == crawler_path(conn, :show)
    end
  end

  describe "with a registered admin user but edit dungeons is disabled" do
    setup [:create_admin]

    test "lists all dungeons", %{conn: conn} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end
  end

  # With a registered user
  describe "index with a registered user" do
    setup [:create_user]

    test "lists all dungeons", %{conn: conn} do
      conn = get conn, dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end
  end

  describe "show with a registered user" do
    setup [:create_user, :create_map_set]

    test "renders show", %{conn: conn, map_set: map_set} do
      conn = get conn, dungeon_path(conn, :show, map_set)
      assert html_response(conn, 200) =~ map_set.name
    end
  end

  describe "show with a registered user but dungeon belongs to someone else" do
    setup [:create_user, :create_map_set]

    test "renders show", %{conn: conn} do
      map_set = fixture(:map_set, insert_user(%{username: "Omer"}).id)
      conn = get conn, dungeon_path(conn, :show, map_set)
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
      conn = post conn, dungeon_path(conn, :create), map_set: @create_attrs
      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == dungeon_path(conn, :show, id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, dungeon_path(conn, :create), map_set: @invalid_attrs
      assert html_response(conn, 200) =~ "New dungeon"
    end
  end

  describe "edit dungeon with a registered user" do
    setup [:create_user, :create_map_set]

    test "renders form for editing chosen map set", %{conn: conn, map_set: map_set} do
      conn = get conn, dungeon_path(conn, :edit, map_set)
      assert html_response(conn, 200) =~ "Edit dungeon"
    end

    test "cannot edit active dungeon", %{conn: conn, map_set: map_set} do
      {:ok, map_set} = Dungeons.update_map_set(map_set, %{active: true})
      conn = get conn, dungeon_path(conn, :edit, map_set)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end
  end

  describe "update dungeon with a registered user" do
    setup [:create_user, :create_map_set]

    test "redirects when data is valid", %{conn: conn, map_set: map_set} do
      conn = put conn, dungeon_path(conn, :update, map_set),
                   map_set: @update_attrs
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
    end

    test "renders errors when data is invalid", %{conn: conn, map_set: map_set} do
      conn = put conn, dungeon_path(conn, :update, map_set), map_set: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit dungeon"
    end

    test "cannot update active dungeon", %{conn: conn, map_set: map_set} do
      {:ok, map_set} = Dungeons.update_map_set(map_set, %{active: true})
      conn = put conn, dungeon_path(conn, :update, map_set), map_set: @update_attrs
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end
  end

  describe "delete dungeon with a registered user" do
    setup [:create_user, :create_map_set]

    test "soft deletes chosen dungeon", %{conn: conn, map_set: map_set} do
      conn = delete conn, dungeon_path(conn, :delete, map_set)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      refute Repo.get!(MapSet, map_set.id).deleted_at == nil
    end
  end

  describe "activate dungeon" do
    setup [:create_user, :create_map_set]

    test "activtes chosen dungeon", %{conn: conn, map_set: map_set} do
      conn = put conn, dungeon_activate_path(conn, :activate, map_set)
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
      assert Repo.get!(MapSet, map_set.id).active
    end

    test "problem activating chosen dungeon", %{conn: conn, map_set: map_set} do
      dungeon = insert_stubbed_dungeon %{map_set_id: map_set.id, width: 40, height: 40}
      inactive_tile_template = insert_tile_template(%{name: "INT", active: false})
      Repo.insert_all(MapTile, [%{dungeon_id: dungeon.id, row: 1, col: 1, tile_template_id: inactive_tile_template.id, z_index: 0}] )
      conn = put conn, dungeon_activate_path(conn, :activate, map_set)
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
      assert get_flash(conn, :error) == "Inactive tiles: INT (id: #{inactive_tile_template.id}) 1 times"
    end

    test "soft deletes the previous version", %{conn: conn, map_set: map_set} do
      new_map_set = insert_stubbed_map_set(%{previous_version_id: map_set.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, dungeon_activate_path(conn, :activate, new_map_set)
      assert redirected_to(conn) == dungeon_path(conn, :show, new_map_set)
      assert Repo.get!(MapSet, map_set.id).deleted_at
      assert Repo.get!(MapSet, new_map_set.id).active
    end
  end

  describe "new_version dungeon" do
    setup [:create_user, :create_map_set]

    test "does not create a new version if dungeon not active", %{conn: conn, map_set: map_set} do
      conn = post conn, dungeon_new_version_path(conn, :new_version, map_set)
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
      assert get_flash(conn, :error) == "Inactive map set"
    end

    test "does not create a new version if dungeon already has a next version", %{conn: conn, map_set: map_set} do
      {:ok, map_set} = Dungeons.update_map_set(map_set, %{active: true})
      _new_map_set = insert_stubbed_map_set(%{previous_version_id: map_set.id, user_id: conn.assigns[:current_user].id})
      conn = post conn, dungeon_new_version_path(conn, :new_version, map_set)
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
      assert get_flash(conn, :error) == "New version already exists"
    end

    test "does not create a new version if dungeon fails validation", %{conn: conn, map_set: map_set} do
      insert_stubbed_dungeon(%{map_set_id: map_set.id, height: 40, width: 40})
      {:ok, map_set} = Dungeons.update_map_set(map_set, %{active: true})
      Admin.update_setting(%{autogen_height: 20, autogen_width: 20, max_width: 20, max_height: 20})
      conn = post conn, dungeon_new_version_path(conn, :new_version, map_set)
      assert get_flash(conn, :error) == "Cannot create new version; dimensions restricted?"
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
    end

    test "creates a new version", %{conn: conn, map_set: map_set} do
      {:ok, map_set} = Dungeons.update_map_set(map_set, %{active: true})
      conn = post conn, dungeon_new_version_path(conn, :new_version, map_set)
      new_version = Repo.get_by!(MapSet, %{previous_version_id: map_set.id})
      assert redirected_to(conn) == dungeon_path(conn, :show, new_version)
      refute Repo.get!(MapSet, map_set.id).deleted_at
      refute Repo.get!(MapSet, new_version.id).active
    end
  end

  describe "test_crawl dungeon" do
    setup [:create_user]

    test "creates an instance", %{conn: conn, user: user} do
      map_set = insert_autogenerated_map_set(%{active: false, user_id: user.id})

      conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, map_set)
      assert redirected_to(conn) == crawler_path(conn, :show)
      location = Player.get_location(user.user_id_hash)
      assert Player.get_map_set(location) == map_set
    end

    test "clears the players previous location if applicable", %{conn: conn, user: user} do
      map_set = insert_autogenerated_map_set(%{active: false, user_id: user.id})

      instance = Enum.at(Repo.preload(insert_autogenerated_map_set_instance(%{active: true}),:maps).maps, 0)
      location = insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})

      _conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, map_set)

      refute Repo.get(DungeonCrawl.Player.Location, location.id)
    end

    test "does not test crawl if the map set has no levels", %{conn: conn, user: user} do
      map_set = fixture(:map_set, user.id)
      conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, map_set)
      assert get_flash(conn, :error) == "Add a dungeon level first"
      assert redirected_to(conn) == dungeon_path(conn, :show, map_set)
    end
  end
  # /With a registered user

  defp create_map_set(opts) do
    map_set = fixture(:map_set, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, map_set: map_set}
  end

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end

  defp create_admin(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end
end

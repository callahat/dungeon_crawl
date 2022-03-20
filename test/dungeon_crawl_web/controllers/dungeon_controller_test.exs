defmodule DungeonCrawlWeb.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.{Dungeon, Tile}
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Player
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder
  alias DungeonCrawl.Shipping
  @create_attrs %{name: "some name"}
  @update_attrs %{name: "new name"}
  @invalid_attrs %{name: ""}

  def fixture(:dungeon, user_id) do
    {:ok, dungeon} = Dungeons.create_dungeon(Map.put(@create_attrs, :user_id, user_id))
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
      conn = post conn, dungeon_path(conn, :create), dungeon: @create_attrs
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
      conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "import dungeon GET without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, dungeon_import_path(conn, :dungeon_import)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "import dungeon POST without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, dungeon_import_path(conn, :dungeon_import)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "export dungeon without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, dungeon_export_path(conn, :dungeon_export, 1)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "export dungeon list without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, dungeon_export_path(conn, :dungeon_export_list)
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

  describe "with a registered user but edit dungeons is disabled" do
    setup [:create_user]

    test "lists all dungeons", %{conn: conn} do
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
      conn = post conn, dungeon_path(conn, :create), dungeon: @create_attrs
      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == dungeon_path(conn, :show, id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, dungeon_path(conn, :create), dungeon: @invalid_attrs
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
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      conn = get conn, dungeon_path(conn, :edit, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end
  end

  describe "update dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "redirects when data is valid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_path(conn, :update, dungeon),
                   dungeon: @update_attrs
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
    end

    test "renders errors when data is invalid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit dungeon"
    end

    test "cannot update active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      conn = put conn, dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
      assert redirected_to(conn) == dungeon_path(conn, :index)
      assert get_flash(conn, :error) == "Cannot edit an active dungeon"
    end
  end

  describe "import dungeon get with a registered user" do
    setup [:create_user]

    test "renders the form", %{conn: conn} do
      insert_dungeon(%{user_id: conn.assigns.current_user.id})
      conn = get conn, dungeon_import_path(conn, :dungeon_import)
      assert html_response(conn, 200) =~ "Import dungeon"
      refute html_response(conn, 200) =~ "UserID"
    end
  end

  describe "import dungeon get with a admin" do
    setup [:create_admin]
    test "renders the form", %{conn: conn} do
      conn = get conn, dungeon_import_path(conn, :dungeon_import)
      assert html_response(conn, 200) =~ "Import dungeon"
      assert html_response(conn, 200) =~ "UserID"
    end
  end

  describe "import dungeon post with a registered user" do
    setup [:create_user]

    test "redirects when data is valid", %{conn: conn} do
      upload = %Plug.Upload{path: "test/support/fixtures/export_fixture_v_1.json", filename: "test.json"}
      conn = post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => ""}
      refute get_flash(conn, :error)
      assert get_flash(conn, :info) == "Importing dungeon."
      assert redirected_to(conn) == dungeon_import_path(conn, :dungeon_import)
      assert [import] = Shipping.list_dungeon_imports()
      assert import.file_name == "test.json"
    end

    test "renders errors when file is invalid", %{conn: conn} do
      upload = %Plug.Upload{path: "test/support/fixtures/export_bad_fixture_v_1.json", filename: "test.json"}
      conn = post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => ""}

      assert redirected_to(conn) == dungeon_import_path(conn, :dungeon_import)
      assert get_flash(conn, :error) == "Import failed; could not parse file"
    end

    test "renders errors when file not found", %{conn: conn} do
      upload = nil
      conn = post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => ""}

      assert redirected_to(conn) == dungeon_import_path(conn, :dungeon_import)
      assert get_flash(conn, :error) == "Import failed; ** (UndefinedFunctionError) function nil.path/0 is undefined"
    end

    test "renders errors when file is already being uploaded", %{conn: conn} do
      upload = %Plug.Upload{path: "test/support/fixtures/export_fixture_v_1.json", filename: "test.json"}
      post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => ""}
      conn = post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => ""}

      assert get_flash(conn, :error) == "Already importing"
      assert redirected_to(conn) == dungeon_import_path(conn, :dungeon_import)
    end

    test "with a line identifier selected for the import", %{conn: conn} do
      upload = %Plug.Upload{path: "test/support/fixtures/export_fixture_v_1.json", filename: "test.json"}
      other_dungeon = insert_dungeon(%{user_id: conn.assigns.current_user.id})
      lid = "#{other_dungeon.line_identifier}"
      conn = post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => lid}

      assert get_flash(conn, :info) == "Importing dungeon."
      assert redirected_to(conn) == dungeon_import_path(conn, :dungeon_import)
      assert [import] = Shipping.list_dungeon_imports()
      assert import.file_name == "test.json"
      assert import.line_identifier == String.to_integer(lid)
    end

    test "with a line identifier that is invalid", %{conn: conn} do
      upload = %Plug.Upload{path: "test/support/fixtures/export_fixture_v_1.json", filename: "test.json"}
      other_user = insert_user()
      other_dungeon = insert_dungeon(%{user_id: other_user.id})
      lid = "#{other_dungeon.line_identifier}"
      conn = post conn, dungeon_import_path(conn, :dungeon_import), %{"file" => upload, "line_identifier" => lid}

      assert get_flash(conn, :error) == "Invalid Line Identifier"
      assert redirected_to(conn) == dungeon_import_path(conn, :dungeon_import)
      assert [] == Shipping.list_dungeon_imports()
    end
  end

  describe "export dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "starts the export when data is valid", %{conn: conn, dungeon: dungeon} do
      EquipmentSeeder.gun()
      SoundSeeder.click()
      SoundSeeder.shoot()

      conn = post conn, dungeon_export_path(conn, :dungeon_export, dungeon)
      assert redirected_to(conn) == dungeon_export_path(conn, :dungeon_export_list)
      assert get_flash(conn, :info) == "Generating download."
    end

    test "renders errors when file is already being uploaded", %{conn: conn, dungeon: dungeon} do
      EquipmentSeeder.gun()
      SoundSeeder.click()
      SoundSeeder.shoot()

      post conn, dungeon_export_path(conn, :dungeon_export, dungeon)
      conn = post conn, dungeon_export_path(conn, :dungeon_export, dungeon)

      assert get_flash(conn, :error) == "Already exporting"
      assert redirected_to(conn) == dungeon_export_path(conn, :dungeon_export_list)
    end
  end

  describe "export dungeon list with a registered user" do
    setup [:create_user]

    test "renders the list", %{conn: conn} do
      conn = get conn, dungeon_export_path(conn, :dungeon_export_list)
      assert html_response(conn, 200) =~ "Export dungeon"
      refute html_response(conn, 200) =~ "UserID"
    end
  end

  describe "export dungeon list with a admin" do
    setup [:create_admin]
    test "renders the list", %{conn: conn} do
      conn = get conn, dungeon_export_path(conn, :dungeon_export_list)
      assert html_response(conn, 200) =~ "Export dungeon"
      assert html_response(conn, 200) =~ "UserID"
    end
  end

  describe "download dungeon export" do
    setup [:create_user]

    test "downloads the dungeon json", %{conn: conn} do
      dungeon = insert_dungeon()
      export = Shipping.create_export!(%{user_id: conn.assigns.current_user.id, dungeon_id: dungeon.id, file_name: "test.json", status: :completed, data: "{}"})
      conn = post conn, dungeon_export_path(conn, :download_dungeon_export, export.id)
      assert json_response(conn, 200)
      assert Enum.member?(
               conn.resp_headers,
               {"content-disposition", "attachment; filename=\"test.json\""})
    end

    test "errors when trying to download someone else's export", %{conn: conn} do
      other_user = insert_user()
      dungeon = insert_dungeon()
      export = Shipping.create_export!(%{user_id: other_user.id, dungeon_id: dungeon.id, file_name: "test.json", status: :completed, data: "{}"})
      conn = post conn, dungeon_export_path(conn, :download_dungeon_export, export.id)
      assert redirected_to(conn) == dungeon_export_path(conn, :dungeon_export_list)
      assert get_flash(conn, :error) == "You do not have access to that"
    end

    test "renders error when the export does not exist", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, dungeon_export_path(conn, :download_dungeon_export, -1)
      end
    end
  end

  describe "delete dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "soft deletes chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, dungeon_path(conn, :delete, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :index)
      refute Repo.get!(Dungeon, dungeon.id).deleted_at == nil
    end
  end

  describe "activate dungeon" do
    setup [:create_user, :create_dungeon]

    test "activtes chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = put conn, dungeon_activate_path(conn, :activate, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert Repo.get!(Dungeon, dungeon.id).active
    end

    test "problem activating chosen dungeon", %{conn: conn, dungeon: dungeon} do
      level = insert_stubbed_level %{dungeon_id: dungeon.id, width: 40, height: 40}
      inactive_tile_template = insert_tile_template(%{name: "INT", active: false})
      Repo.insert_all(Tile, [%{level_id: level.id, row: 1, col: 1, tile_template_id: inactive_tile_template.id, z_index: 0}] )
      conn = put conn, dungeon_activate_path(conn, :activate, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert get_flash(conn, :error) == "Inactive tiles: INT (id: #{inactive_tile_template.id}) 1 times"
    end

    test "soft deletes the previous version", %{conn: conn, dungeon: dungeon} do
      new_dungeon = insert_stubbed_dungeon(%{previous_version_id: dungeon.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, dungeon_activate_path(conn, :activate, new_dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, new_dungeon)
      assert Repo.get!(Dungeon, dungeon.id).deleted_at
      assert Repo.get!(Dungeon, new_dungeon.id).active
    end
  end

  describe "new_version dungeon" do
    setup [:create_user, :create_dungeon]

    test "does not create a new version if dungeon not active", %{conn: conn, dungeon: dungeon} do
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert get_flash(conn, :error) == "Inactive dungeon"
    end

    test "does not create a new version if dungeon already has a next version", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      _new_dungeon = insert_stubbed_dungeon(%{previous_version_id: dungeon.id, user_id: conn.assigns[:current_user].id})
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
      assert get_flash(conn, :error) == "New version already exists"
    end

    test "does not create a new version if dungeon fails validation", %{conn: conn, dungeon: dungeon} do
      insert_stubbed_level(%{dungeon_id: dungeon.id, height: 40, width: 40})
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      Admin.update_setting(%{autogen_height: 20, autogen_width: 20, max_width: 20, max_height: 20})
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      assert get_flash(conn, :error) == "Cannot create new version; dimensions restricted?"
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
    end

    test "creates a new version", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      conn = post conn, dungeon_new_version_path(conn, :new_version, dungeon)
      new_version = Repo.get_by!(Dungeon, %{previous_version_id: dungeon.id})
      assert redirected_to(conn) == dungeon_path(conn, :show, new_version)
      refute Repo.get!(Dungeon, dungeon.id).deleted_at
      refute Repo.get!(Dungeon, new_version.id).active
    end
  end

  describe "test_crawl dungeon" do
    setup [:create_user]

    test "creates an instance", %{conn: conn, user: user} do
      Equipment.Seeder.gun()

      dungeon = insert_autogenerated_dungeon(%{active: false, user_id: user.id})

      conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, dungeon)
      assert redirected_to(conn) == crawler_path(conn, :show)
      location = Player.get_location(user.user_id_hash)
      assert Player.get_dungeon(location) == dungeon
    end

    test "clears the players previous location if applicable", %{conn: conn, user: user} do
      Equipment.Seeder.gun()

      dungeon = insert_autogenerated_dungeon(%{active: false, user_id: user.id, state: "starting_equipment: gun"})

      #level_instance = Enum.at(Repo.preload(insert_autogenerated_dungeon_instance(%{active: true}),:levels).levels, 0)
      level_instance = insert_autogenerated_level_instance(%{active: true})
      location = insert_player_location(%{level_instance_id: level_instance.id, user_id_hash: user.user_id_hash})

      _conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, dungeon)

      refute Repo.get(DungeonCrawl.Player.Location, location.id)
    end

    test "does not test crawl if the dungeon has no levels", %{conn: conn, user: user} do
      dungeon = fixture(:dungeon, user.id)
      conn = post conn, dungeon_test_crawl_path(conn, :test_crawl, dungeon)
      assert get_flash(conn, :error) == "Add a level first"
      assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
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

  defp create_admin(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    conn = assign(build_conn(), :current_user, user)
    {:ok, conn: conn, user: user}
  end
end

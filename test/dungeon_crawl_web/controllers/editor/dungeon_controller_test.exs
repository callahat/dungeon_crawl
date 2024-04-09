defmodule DungeonCrawlWeb.Editor.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.{Dungeon, Tile}
  alias DungeonCrawl.DungeonProcesses.DungeonRegistry
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Games
  alias DungeonCrawl.Player
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder
  alias DungeonCrawl.Shipping
  alias DungeonCrawl.Shipping.DungeonImports
  @create_attrs %{name: "some name"}
  @update_attrs %{name: "new name"}
  @invalid_attrs %{name: "", state_variables: ["flag", "starting_equipment"], state_values: ["true", "baditem"]}

  @create_import_attrs %{data: "{}", file_name: "import.json"}

  def fixture(:dungeon, user_id) do
    {:ok, dungeon} = Dungeons.create_dungeon(Map.merge(@create_attrs, %{user_id: user_id, state: %{"banner" => "hark"}}))
    dungeon
  end

  def fixture(:dungeon_import, user_id, dungeon_id \\ nil) do
    Shipping.create_import!(Map.merge(@create_import_attrs, %{user_id: user_id, dungeon_id: dungeon_id}))
  end

  # Without registered user
  describe "index without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, edit_dungeon_path(conn, :index)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "show without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, edit_dungeon_path(conn, :show, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "new dungeon without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, edit_dungeon_path(conn, :new)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "create dungeon without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, edit_dungeon_path(conn, :create), dungeon: @create_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "edit dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = get conn, edit_dungeon_path(conn, :edit, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "update dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = put conn, edit_dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "import dungeon GET without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, edit_dungeon_import_path(conn, :dungeon_import)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "import dungeon show GET without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, edit_dungeon_import_path(conn, :dungeon_import_show, 1)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "import dungeon update without a registered user" do
    setup [:create_dungeon_import]

    test "redirects", %{conn: conn, dungeon_import: dungeon_import} do
      conn = post conn, edit_dungeon_import_path(conn, :dungeon_import_update, dungeon_import.id)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "export dungeon without a registered user" do
    test "redirects", %{conn: conn} do
      conn = post conn, edit_dungeon_export_path(conn, :dungeon_export, 1)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "export dungeon list without a registered user" do
    test "redirects", %{conn: conn} do
      conn = get conn, edit_dungeon_export_path(conn, :dungeon_export_list)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end

  describe "delete dungeon without a registered user" do
    setup [:create_dungeon]

    test "redirects", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, edit_dungeon_path(conn, :delete, dungeon)
      assert redirected_to(conn) == page_path(conn, :index)
    end
  end
  # /Without registered user

  describe "with a registered user but edit dungeons is disabled" do
    setup [:create_user]

    test "lists all dungeons", %{conn: conn} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, edit_dungeon_path(conn, :index)
      assert redirected_to(conn) == dungeon_path(conn, :index)
    end
  end

  describe "with a registered admin user but edit dungeons is disabled" do
    setup [:create_admin]

    test "lists all dungeons", %{conn: conn} do
      Admin.update_setting(%{non_admin_dungeons_enabled: false})
      conn = get conn, edit_dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end
  end

  # With a registered user
  describe "index with a registered user" do
    setup [:create_user]

    test "lists all dungeons", %{conn: conn} do
      conn = get conn, edit_dungeon_path(conn, :index)
      assert html_response(conn, 200) =~ "Listing dungeons"
    end
  end

  describe "show with a registered user" do
    setup [:create_user, :create_dungeon]

    test "renders show", %{conn: conn, dungeon: dungeon} do
      conn = get conn, edit_dungeon_path(conn, :show, dungeon)
      assert html_response(conn, 200) =~ dungeon.name
    end

    test "cannot show a dungeon that is still importing", %{conn: conn, dungeon: dungeon} do
      Dungeons.update_dungeon(dungeon, %{importing: true})
      conn = get conn, edit_dungeon_path(conn, :show, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert Flash.get(conn.assigns.flash, :error) == "Import still in progress, try again later."
    end
  end

  describe "show with a registered user but dungeon belongs to someone else" do
    setup [:create_user, :create_dungeon]

    test "renders show", %{conn: conn} do
      dungeon = fixture(:dungeon, insert_user(%{username: "Omer"}).id)
      conn = get conn, edit_dungeon_path(conn, :show, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
    end
  end

  describe "new dungeon with a registered user" do
    setup [:create_user]

    test "renders form", %{conn: conn} do
      conn = get conn, edit_dungeon_path(conn, :new)
      assert html_response(conn, 200) =~ "New dungeon"
    end
  end

  describe "create dungeon with a registered user" do
    setup [:create_user]

    test "redirects to show when data is valid", %{conn: conn} do
      conn = post conn, edit_dungeon_path(conn, :create), dungeon: @create_attrs
      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, edit_dungeon_path(conn, :create), dungeon: @invalid_attrs
      assert html_response(conn, 200) =~ "New dungeon"
      assert html_response(conn, 200) =~ "starting_equipment contains invalid items: `[&quot;baditem&quot;]`"
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_variables\]\[\]" type="text" value="flag">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_values\]\[\]" type="text" value="true">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_variables\]\[\]" type="text" value="starting_equipment">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_values\]\[\]" type="text" value="baditem">|
    end
  end

  describe "edit dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "renders form for editing chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = get conn, edit_dungeon_path(conn, :edit, dungeon)
      assert html_response(conn, 200) =~ "Edit dungeon"
    end

    test "cannot edit active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      conn = get conn, edit_dungeon_path(conn, :edit, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert Flash.get(conn.assigns.flash, :error) == "Cannot edit an active dungeon"
    end

    test "cannot edit a dungeon that is still importing", %{conn: conn, dungeon: dungeon} do
      Dungeons.update_dungeon(dungeon, %{importing: true})
      conn = get conn, edit_dungeon_path(conn, :edit, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert Flash.get(conn.assigns.flash, :error) == "Import still in progress, try again later."
    end
  end

  describe "update dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "redirects when data is valid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, edit_dungeon_path(conn, :update, dungeon),
                   dungeon: @update_attrs
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
    end

    test "renders errors when data is invalid", %{conn: conn, dungeon: dungeon} do
      conn = put conn, edit_dungeon_path(conn, :update, dungeon), dungeon: @invalid_attrs
      assert html_response(conn, 200) =~ "Edit dungeon"
      assert html_response(conn, 200) =~ "starting_equipment contains invalid items: `[&quot;baditem&quot;]`"
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_variables\]\[\]" type="text" value="banner">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_values\]\[\]" type="text" value="hark">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_variables\]\[\]" type="text" value="flag">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_values\]\[\]" type="text" value="true">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_variables\]\[\]" type="text" value="starting_equipment">|
      assert html_response(conn, 200) =~ ~r|<input class="form-control" name="dungeon\[state_values\]\[\]" type="text" value="baditem">|
    end

    test "cannot update active dungeon", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      conn = put conn, edit_dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert Flash.get(conn.assigns.flash, :error) == "Cannot edit an active dungeon"
    end

    test "cannot update a dungeon that is still importing", %{conn: conn, dungeon: dungeon} do
      Dungeons.update_dungeon(dungeon, %{importing: true})
      conn = put conn, edit_dungeon_path(conn, :update, dungeon), dungeon: @update_attrs
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      assert Flash.get(conn.assigns.flash, :error) == "Import still in progress, try again later."
    end
  end

  describe "import dungeon get with a registered user" do
    setup [:create_user]

    test "renders the form", %{conn: conn} do
      insert_dungeon(%{user_id: conn.assigns.current_user.id})
      conn = get conn, edit_dungeon_import_path(conn, :dungeon_import)
      assert html_response(conn, 200) =~ "Import dungeon"
      assert html_response(conn, 200) =~ "Filename"
    end
  end

  describe "import dungeon show GET with a registered user" do
    setup [:create_user, :create_dungeon_import]

    test "shows the import", %{conn: conn, dungeon_import: dungeon_import} do
      conn = get conn, edit_dungeon_import_path(conn, :dungeon_import_show, dungeon_import.id)
      assert html_response(conn, 200) =~ "Dungeon Import"
      assert html_response(conn, 200) =~ "Log"
    end
  end

  describe "import dungeon update with a registered user" do
    setup [:create_user, :create_dungeon_import, :link_dock_worker]

    test "redirects and shows error when import not waiting",
         %{conn: conn, dungeon_import: dungeon_import} do
      conn = post conn, edit_dungeon_import_path(conn, :dungeon_import_update, dungeon_import.id), %{"action" => %{"26" => "use_existing"}}
      assert redirected_to(conn) == edit_dungeon_import_path(conn, :dungeon_import)
      assert Flash.get(conn.assigns.flash, :error) == "Cannot continue with that dungeon import"
    end

    test "invalid action updates are ignored",
         %{conn: conn, dungeon_import: dungeon_import} do
      {:ok, _import} = Shipping.update_import(dungeon_import, %{status: :waiting})
      conn = post conn, edit_dungeon_import_path(conn, :dungeon_import_update, dungeon_import.id), %{"action" => %{"1" => "create_new"}}
      assert redirected_to(conn) == edit_dungeon_import_path(conn, :dungeon_import)
      assert Flash.get(conn.assigns.flash, :info) == "Continuing import"
      assert [] == DungeonImports.get_asset_imports(dungeon_import.id)
    end

    test "continues the import when waiting",
         %{conn: conn, dungeon_import: dungeon_import} do
      {:ok, _import} = Shipping.update_import(dungeon_import, %{status: :waiting})
      asset_import = DungeonImports.create_asset_import!(dungeon_import.id, :sounds, "tmp_sound", "beep", %{}, %{})
      conn = post conn, edit_dungeon_import_path(conn, :dungeon_import_update, dungeon_import.id), %{"action" => %{asset_import.id => "create_new"}}
      assert redirected_to(conn) == edit_dungeon_import_path(conn, :dungeon_import)
      assert Flash.get(conn.assigns.flash, :info) == "Continuing import"
      assert [asset_import] = DungeonImports.get_asset_imports(dungeon_import.id)
      assert asset_import.action == :create_new
    end

    test "when the import belongs to someone else",  %{conn: conn, dungeon_import: dungeon_import} do
      other_user = insert_user()
      {:ok, _import} = Shipping.update_import(dungeon_import, %{user_id: other_user.id, status: :waiting})
      asset_import = DungeonImports.create_asset_import!(dungeon_import.id, :sounds, "tmp_sound", "beep", %{}, %{})

      updated_conn = post conn, edit_dungeon_import_path(conn, :dungeon_import_update, dungeon_import.id), %{"action" => %{asset_import.id => "create_new"}}
      assert Flash.get(updated_conn.assigns.flash, :error) == "You do not have access to that"
      assert redirected_to(updated_conn) == edit_dungeon_import_path(updated_conn, :dungeon_import)
      assert length(Dungeons.list_dungeons()) == 0

      # but the user is an admin
      conn = assign(conn,  :current_user, %{conn.assigns.current_user | is_admin: true})

      updated_conn = post conn, edit_dungeon_import_path(conn, :dungeon_import_update, dungeon_import.id), %{"action" => %{asset_import.id => "create_new"}}
      assert redirected_to(updated_conn) == edit_dungeon_import_path(updated_conn, :dungeon_import)
      assert Flash.get(updated_conn.assigns.flash, :info) == "Continuing import"
      assert [asset_import] = DungeonImports.get_asset_imports(dungeon_import.id)
      assert asset_import.action == :create_new
    end
  end

  describe "export dungeon with a registered user" do
    setup [:create_user, :create_dungeon, :link_dock_worker]

    test "starts the export when data is valid", %{conn: conn, dungeon: dungeon} do
      EquipmentSeeder.gun()
      SoundSeeder.click()
      SoundSeeder.shoot()

      assert length(Shipping.list_dungeon_exports()) == 0
      conn = post conn, edit_dungeon_export_path(conn, :dungeon_export, dungeon)
      assert redirected_to(conn) == edit_dungeon_export_path(conn, :dungeon_export_list)
      assert length(Shipping.list_dungeon_exports()) == 1
    end

    test "renders errors when file is already being uploaded", %{conn: conn, dungeon: dungeon} do
      EquipmentSeeder.gun()
      SoundSeeder.click()
      SoundSeeder.shoot()

      post conn, edit_dungeon_export_path(conn, :dungeon_export, dungeon)
      conn = post conn, edit_dungeon_export_path(conn, :dungeon_export, dungeon)

      assert redirected_to(conn) == edit_dungeon_export_path(conn, :dungeon_export_list)
      assert length(Shipping.list_dungeon_exports()) == 1
    end

    test "when the dungeon belongs to someone else",  %{conn: conn, dungeon: dungeon} do
      other_user = insert_user()
      Dungeons.update_dungeon(dungeon, %{user_id: other_user.id})

      updated_conn = post conn, edit_dungeon_export_path(conn, :dungeon_export, dungeon)
      assert Flash.get(updated_conn.assigns.flash, :error) == "You do not have access to that"
      assert redirected_to(updated_conn) == edit_dungeon_path(updated_conn, :index)
      assert length(Shipping.list_dungeon_exports()) == 0

      # but the user is an admin
      conn = assign(conn,  :current_user, %{conn.assigns.current_user | is_admin: true})

      updated_conn = post conn, edit_dungeon_export_path(conn, :dungeon_export, dungeon)
      assert redirected_to(updated_conn) == edit_dungeon_export_path(updated_conn, :dungeon_export_list)
      assert length(Shipping.list_dungeon_exports()) == 1
    end
  end

  describe "export dungeon list with a registered user" do
    setup [:create_user]

    test "renders the list", %{conn: conn} do
      conn = get conn, edit_dungeon_export_path(conn, :dungeon_export_list)
      assert html_response(conn, 200) =~ "Export dungeon"
      assert html_response(conn, 200) =~ "Filename"
    end
  end

  describe "download dungeon export" do
    setup [:create_user, :link_dock_worker]

    test "downloads the dungeon json", %{conn: conn} do
      dungeon = insert_dungeon()
      export = Shipping.create_export!(%{user_id: conn.assigns.current_user.id, dungeon_id: dungeon.id, file_name: "test.json", status: :completed, data: "{}"})
      conn = get conn, edit_dungeon_export_path(conn, :download_dungeon_export, export.id)
      assert json_response(conn, 200)
      assert Enum.member?(
               conn.resp_headers,
               {"content-disposition", "attachment; filename=\"test.json\""})
    end

    test "when trying to download someone else's export", %{conn: conn} do
      other_user = insert_user()
      dungeon = insert_dungeon()
      export = Shipping.create_export!(%{user_id: other_user.id, dungeon_id: dungeon.id, file_name: "test.json", status: :completed, data: "{}"})
      updated_conn = get conn, edit_dungeon_export_path(conn, :download_dungeon_export, export.id)
      assert redirected_to(updated_conn) == edit_dungeon_export_path(updated_conn, :dungeon_export_list)
      assert Flash.get(updated_conn.assigns.flash, :error) == "You do not have access to that"

      # when the user is an admin
      conn = assign(conn,  :current_user, %{conn.assigns.current_user | is_admin: true})

      updated_conn = get conn, edit_dungeon_export_path(conn, :download_dungeon_export, export.id)
      assert json_response(updated_conn, 200)
      assert Enum.member?(
               updated_conn.resp_headers,
               {"content-disposition", "attachment; filename=\"test.json\""})
    end

    test "renders error when the export does not exist", %{conn: conn} do
      assert_error_sent 404, fn ->
        get conn, edit_dungeon_export_path(conn, :download_dungeon_export, -1)
      end
    end
  end

  describe "delete dungeon with a registered user" do
    setup [:create_user, :create_dungeon]

    test "soft deletes chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = delete conn, edit_dungeon_path(conn, :delete, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :index)
      refute Repo.get!(Dungeon, dungeon.id).deleted_at == nil
    end
  end

  describe "activate dungeon" do
    setup [:create_user, :create_dungeon]

    test "activtes chosen dungeon", %{conn: conn, dungeon: dungeon} do
      conn = put conn, edit_dungeon_activate_path(conn, :activate, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
      assert Repo.get!(Dungeon, dungeon.id).active
    end

    test "problem activating chosen dungeon", %{conn: conn, dungeon: dungeon} do
      level = insert_stubbed_level %{dungeon_id: dungeon.id, width: 40, height: 40}
      inactive_tile_template = insert_tile_template(%{name: "INT", active: false})
      Repo.insert_all(Tile, [%{level_id: level.id, row: 1, col: 1, tile_template_id: inactive_tile_template.id, z_index: 0}] )
      conn = put conn, edit_dungeon_activate_path(conn, :activate, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
      assert Flash.get(conn.assigns.flash, :error) == "Inactive tiles: INT (id: #{inactive_tile_template.id}) 1 times"
    end

    test "soft deletes the previous version", %{conn: conn, dungeon: dungeon} do
      new_dungeon = insert_stubbed_dungeon(%{previous_version_id: dungeon.id, user_id: conn.assigns[:current_user].id})
      conn = put conn, edit_dungeon_activate_path(conn, :activate, new_dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, new_dungeon)
      assert Repo.get!(Dungeon, dungeon.id).deleted_at
      assert Repo.get!(Dungeon, new_dungeon.id).active
    end

    test "converts saves when new version is activated", %{conn: conn, dungeon: dungeon} do
      insert_stubbed_level(%{dungeon_id: dungeon.id})
      {:ok, dungeon} = Dungeons.activate_dungeon(dungeon)

      player = insert_player_location(%{user_id_hash: "one", tile_instance_id: nil})

      {:ok, %{dungeon: di}} = DungeonCrawl.DungeonInstances.create_dungeon(dungeon, "test", false, true)
      [header] = Repo.preload(di, :level_headers).level_headers
      level_instance = DungeonCrawl.DungeonInstances.find_or_create_level(header, player.id)

      {:ok, save} =
        %{user_id_hash: player.user_id_hash,
          player_location_id: player.id,
          host_name: di.host_name,
          level_name: "Level 1"}
        |> Map.merge(%{level_instance_id: level_instance.id, row: 2, col: 3, z_index: 3, state: %{"player" => true}})
        |> Games.create_save()

      {:ok, new_dungeon} = Dungeons.create_new_dungeon_version(dungeon)

      conn = put conn, edit_dungeon_activate_path(conn, :activate, new_dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, new_dungeon)
      assert Repo.get!(Dungeon, dungeon.id).deleted_at
      assert Repo.get!(Dungeon, new_dungeon.id).active

      # it'll be a newer record which means the record id will be higher than the
      # level instance on the original save record
      assert Games.get_save(save.id).level_instance_id > save.level_instance_id
    end
  end

  describe "new_version dungeon" do
    setup [:create_user, :create_dungeon]

    test "does not create a new version if dungeon not active", %{conn: conn, dungeon: dungeon} do
      conn = post conn, edit_dungeon_new_version_path(conn, :new_version, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
      assert Flash.get(conn.assigns.flash, :error) == "Inactive dungeon"
    end

    test "does not create a new version if dungeon already has a next version", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      _new_dungeon = insert_stubbed_dungeon(%{previous_version_id: dungeon.id, user_id: conn.assigns[:current_user].id})
      conn = post conn, edit_dungeon_new_version_path(conn, :new_version, dungeon)
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
      assert Flash.get(conn.assigns.flash, :error) == "New version already exists"
    end

    test "does not create a new version if dungeon fails validation", %{conn: conn, dungeon: dungeon} do
      insert_stubbed_level(%{dungeon_id: dungeon.id, height: 40, width: 40})
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      Admin.update_setting(%{autogen_height: 20, autogen_width: 20, max_width: 20, max_height: 20})
      conn = post conn, edit_dungeon_new_version_path(conn, :new_version, dungeon)
      assert Flash.get(conn.assigns.flash, :error) == "Cannot create new version; dimensions restricted?"
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
    end

    test "creates a new version", %{conn: conn, dungeon: dungeon} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: true})
      conn = post conn, edit_dungeon_new_version_path(conn, :new_version, dungeon)
      new_version = Repo.get_by!(Dungeon, %{previous_version_id: dungeon.id})
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, new_version)
      refute Repo.get!(Dungeon, dungeon.id).deleted_at
      refute Repo.get!(Dungeon, new_version.id).active
    end
  end

  describe "test_crawl dungeon" do
    setup [:create_user]

    test "creates an instance", %{conn: conn, user: user} do
      dungeon = insert_stubbed_dungeon(%{active: false, user_id: user.id}, %{}, [[%{character: ".", row: 1, col: 1, z_index: 0}]])

      conn = post conn, edit_dungeon_test_crawl_path(conn, :test_crawl, dungeon)
      assert redirected_to(conn) == crawler_path(conn, :show)
      location = Player.get_location(user.user_id_hash)
      assert Player.get_dungeon(location) == dungeon

      # cleanup
      DungeonRegistry.remove(DungeonInstanceRegistry, dungeon.id)
    end

    test "clears the players previous location if applicable", %{conn: conn, user: user} do
      Equipment.Seeder.gun()

      dungeon = insert_stubbed_dungeon(%{active: false, user_id: user.id}, %{}, [[%{character: ".", row: 1, col: 1, z_index: 0}]])

      #level_instance = Enum.at(Repo.preload(insert_autogenerated_dungeon_instance(%{active: true}),:levels).levels, 0)
      level_instance = insert_autogenerated_level_instance(%{active: true})
      location = insert_player_location(%{level_instance_id: level_instance.id, user_id_hash: user.user_id_hash})

      _conn = post conn, edit_dungeon_test_crawl_path(conn, :test_crawl, dungeon)

      refute Repo.get(DungeonCrawl.Player.Location, location.id)

      # cleanup
      DungeonRegistry.remove(DungeonInstanceRegistry, dungeon.id)
      DungeonRegistry.remove(DungeonInstanceRegistry, level_instance.dungeon_instance_id)
    end

    test "does not test crawl if the dungeon has no levels", %{conn: conn, user: user} do
      dungeon = fixture(:dungeon, user.id)
      conn = post conn, edit_dungeon_test_crawl_path(conn, :test_crawl, dungeon)
      assert Flash.get(conn.assigns.flash, :error) == "Add a level first"
      assert redirected_to(conn) == edit_dungeon_path(conn, :show, dungeon)
    end
  end
  # /With a registered user

  defp create_dungeon(opts) do
    dungeon = fixture(:dungeon, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )
    {:ok, conn: opts.conn, dungeon: dungeon}
  end

  defp create_dungeon_import(opts) do
    dungeon_import = fixture(:dungeon_import, (opts.conn.assigns[:current_user] || insert_user(%{username: "CSwaggins"})).id )

    {:ok, conn: opts.conn, dungeon_import: dungeon_import}
  end

  defp link_dock_worker(opts) do
    # to ensure the dock worker is killed when the test is done; reduces error noise
    # that doesn't actually fail the test
    {:ok, dock_worker} = GenServer.start_link(DungeonCrawl.Shipping.DockWorker, %{})

    on_exit(fn -> Process.exit(dock_worker, :kill) end)

    {:ok, conn: opts.conn}
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

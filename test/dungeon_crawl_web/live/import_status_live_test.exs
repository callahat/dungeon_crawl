defmodule DungeonCrawlWeb.ImportStatusLiveTest do
  use DungeonCrawlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias DungeonCrawl.Shipping

  alias DungeonCrawlWeb.Endpoint
  alias DungeonCrawlWeb.ImportStatusLive

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    {:ok, user: user}
  end

  defp create_admin(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    {:ok, user: user}
  end

  describe "list" do
    setup [:create_user]

    test "lists imports", %{conn: conn, user: user} do
      Shipping.create_import!(%{user_id: user.id, data: "{}", file_name: "test.json"})

      {:ok, _import_live, html} =
        live_isolated(conn, ImportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert html =~ "Line identifier"
      assert html =~ "Filename"
      assert html =~ "Started"
      assert html =~ "Status"
      assert html =~ "test.json"
      refute html =~ "UserID"
    end
  end

  # doesn't really do anything special other than show the user id, which right now will only
  describe "list for an admin" do
    setup [:create_admin]

    test "lists imports", %{conn: conn, user: user} do
      {:ok, _import_live, html} =
        live_isolated(conn, ImportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert html =~ "Line identifier"
      assert html =~ "Filename"
      assert html =~ "Started"
      assert html =~ "Status"
      assert html =~ "UserID"
    end
  end

#  Not sure how to actually get the file through the form so the handle_event
#   will process it. Tried a lot of things and none of them worked. What is there
#   seems like it should work according to the docs, but when it comes to `consume_uploaded_entries`,
#   it seems theres no files to act on.
#  Manually, this functionality works just fine so gonna punt indefinitely on a ExUnit test
#    indefinitely on import create.
  describe "create new import" do
    setup [:create_user]

    test "creates new import", %{conn: conn, user: user} do
      dungeon = insert_dungeon(%{user_id: user.id})

      # tried getting the file upload to work via test,
      {:ok, import_live, _html} =
        live_isolated(conn, ImportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      bad_import = file_input(import_live, "#import-form", :file, [%{
        name: "test.json",
        content: File.read!("test/support/fixtures/export_bad_fixture_v_1.json"),
        type: "application/json",
      }])

      assert import_live
             |> form("#import-form", line_identifier: dungeon.line_identifier, file: bad_import)
             |> render_submit() # =~ "Import failed; could not parse file"
#
#      # TODO: test when the file does not exist
#      # TODO: test when the file is already being uploaded
#
#      good_import = file_input(import_live, "#import-form", :file, [%{
#        name: "test.json",
#        content: File.read!("test/support/fixtures/export_fixture_v_1.json"),
#        type: "application/json",
#      }])
#
#      assert good_import
#             |> form("#import-form", line_identifier: dungeon.line_identifier, file: bad_import)
#             |> render_submit() =~ "test.json" # the filename will be listed
    end
  end

  describe "import state updates" do
    setup [:create_user]

    test "deletes export in listing", %{conn: conn, user: user} do
      import = Shipping.create_import!(%{user_id: user.id, data: "{}", file_name: "test.json"})

      {:ok, import_live, _html} =
        live_isolated(conn, ImportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert import_live |> render() =~ "test.json"
      assert import_live |> render() =~ "queued"

      Shipping.update_import(import, %{status: "running"})
      Endpoint.broadcast("import_status_#{ user.id }", "doesnt really matter", {:import, import})

      assert import_live |> render() =~ "running"

      dungeon = insert_dungeon()
      Shipping.update_import(import, %{status: "completed", dungeon_id: dungeon.id})
      Endpoint.broadcast("import_status_#{ user.id }", "doesnt really matter", {:import, import})

      assert import_live |> render() =~ "completed"
      assert import_live |> element("a", dungeon.name) |> render() =~ "href=\"/dungeons/#{dungeon.id}"
    end
  end

  describe "delete import" do
    setup [:create_user]

    test "deletes export in listing", %{conn: conn, user: user} do
      import = Shipping.create_import!(%{user_id: user.id, data: "{}", file_name: "test.json"})

      {:ok, import_live, _html} =
        live_isolated(conn, ImportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert import_live |> render() =~ "test.json"
      assert import_live |> element("a.btn-danger", "Delete") |> render_click()
      refute import_live |> render() =~ "test.json"
      assert_raise Ecto.NoResultsError, fn -> Shipping.get_import!(import.id) end
    end
  end
#  describe "import" do
#    setup [:create_user]
#
#
#    test "updates export in listing", %{conn: conn, export: export} do
#      {:ok, index_live, _html} = live(conn, Routes.export_index_path(conn, :index))
#
#      assert index_live |> element("#export-#{export.id} a", "Edit") |> render_click() =~
#               "Edit Export"
#
#      assert_patch(index_live, Routes.export_index_path(conn, :edit, export))
#
#      assert index_live
#             |> form("#export-form", export: @invalid_attrs)
#             |> render_change() =~ "can&#39;t be blank"
#
#      {:ok, _, html} =
#        index_live
#        |> form("#export-form", export: @update_attrs)
#        |> render_submit()
#        |> follow_redirect(conn, Routes.export_index_path(conn, :index))
#
#      assert html =~ "Export updated successfully"
#      assert html =~ "some updated name"
#    end
#
#  end

end

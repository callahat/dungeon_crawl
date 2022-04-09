defmodule DungeonCrawlWeb.ExportStatusLiveTest do
  use DungeonCrawlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias DungeonCrawl.Shipping

  alias DungeonCrawlWeb.Endpoint
  alias DungeonCrawlWeb.ExportStatusLive

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

    test "lists exports", %{conn: conn, user: user} do
      dungeon = insert_dungeon()
      Shipping.create_export!(%{user_id: user.id, dungeon_id: dungeon.id})

      {:ok, _export_live, html} =
        live_isolated(conn, ExportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert html =~ "Dungeon ID"
      assert html =~ "Filename"
      assert html =~ "Started"
      assert html =~ "Status"
      assert html =~ "#{ dungeon.id }"
      refute html =~ "User"
    end
  end

  # doesn't really do anything special other than show the user id, which right now will only
  describe "list for an admin" do
    setup [:create_admin]

    test "lists exports", %{conn: conn, user: user} do
      {:ok, _export_live, html} =
        live_isolated(conn, ExportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert html =~ "Dungeon ID"
      assert html =~ "Filename"
      assert html =~ "Started"
      assert html =~ "Status"
      assert html =~ "User"
    end
  end

  describe "export state updates" do
    setup [:create_user]

    test "exports update when refresh message received", %{conn: conn, user: user} do
      dungeon = insert_dungeon()
      export = Shipping.create_export!(%{user_id: user.id, dungeon_id: dungeon.id})

      {:ok, export_live, _html} =
        live_isolated(conn, ExportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert export_live |> render() =~ "queued"

      Shipping.update_export(export, %{status: "running"})

      # noop when message for someone else
      Endpoint.broadcast("export_status_#{ user.id + 1 }", "refresh_status", {:export, export})
      assert export_live |> render() =~ "queued"
      Endpoint.broadcast("export_status", "refresh_status", {:export, export})
      assert export_live |> render() =~ "queued"

      Endpoint.broadcast("export_status_#{ user.id }", "refresh_status", {:export, export})
      assert export_live |> render() =~ "running"

      Shipping.update_export(export, %{status: "completed", file_name: "test.json"})
      Endpoint.broadcast("export_status_#{ user.id }", "refresh_status", {:export, export})

      assert export_live |> render() =~ "test.json"
      assert export_live |> render() =~ "completed"
      assert export_live |> element("a", "test.json") |> render() =~ "href=\"/dungeons/export/#{export.id}"
    end
  end

  describe "error message" do
    setup [:create_user]

    test "puts a message in error flash when an error broadcast recieved", %{conn: conn, user: user} do
      {:ok, export_live, _html} =
        live_isolated(conn, ExportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      Endpoint.broadcast("export_status_#{ user.id }", "error", nil)

      assert export_live |> render() =~ "Something went wrong"
    end
  end

  describe "delete export" do
    setup [:create_user]

    test "deletes export in listing", %{conn: conn, user: user} do
      dungeon = insert_dungeon()
      export = Shipping.create_export!(%{user_id: user.id, dungeon_id: dungeon.id, file_name: "test.json"})

      {:ok, export_live, _html} =
        live_isolated(conn, ExportStatusLive, session: %{"user_id_hash" => user.user_id_hash})

      assert export_live |> render() =~ "test.json"
      assert export_live |> element("a.btn-danger", "Delete") |> render_click()
      refute export_live |> render() =~ "test.json"
      assert_raise Ecto.NoResultsError, fn -> Shipping.get_export!(export.id) end
    end
  end
end

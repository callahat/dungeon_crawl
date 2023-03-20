defmodule DungeonCrawlWeb.SavedGamesLiveTest do
  use DungeonCrawlWeb.ConnCase

  import Phoenix.LiveViewTest
  import DungeonCrawl.GamesFixtures

  alias DungeonCrawl.Repo

  alias DungeonCrawlWeb.SavedGamesLive

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    save = save_fixture(%{user_id_hash: user.user_id_hash})
           |> Repo.preload(dungeon_instance: :dungeon)
    {:ok, user: user, save: save}
  end

  describe "list for signed in user" do
    setup [:create_user]

    test "lists dungeons with saved games", %{conn: conn, user: user, save: save} do

      {:ok, saved_games_live, html} =
        live_isolated(conn, SavedGamesLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert html =~ "focus#{ save.dungeon_instance.dungeon.id }"
      assert html =~ save.dungeon_instance.dungeon.name
      assert saved_games_live |> render() =~ "Select a saved game by its dungeon on the left to learn more about it."
    end
  end

  describe "focus dungeon with saved game" do
    setup [:create_user]

    test "displays information about the save", %{conn: conn, user: user, save: save} do
      {:ok, saved_games_live, _html} =
        live_isolated(conn, SavedGamesLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert saved_games_live |> render() =~ "focus#{ save.dungeon_instance.dungeon.id }"
      assert saved_games_live |> element("[phx-click='focus#{save.dungeon_instance.dungeon.id}']") |> render_click()
      refute saved_games_live |> render() =~ "Select a dungeon on the left to learn more about it"
      assert saved_games_live |> render() =~ "Saved Games"
      assert saved_games_live |> render() =~ "Load"
      assert saved_games_live |> element(".col-7") |> render() =~ save.dungeon_instance.dungeon.name
    end
  end

  describe "unfocus saved game" do
    setup [:create_user]

    test "clears the focused dungeon", %{conn: conn, user: user, save: save} do
      {:ok, saved_games_live, _html} =
        live_isolated(conn, SavedGamesLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert saved_games_live |> element("[phx-click='focus#{save.dungeon_instance.dungeon.id}']") |> render_click()

      assert saved_games_live |> render() =~ "unfocus"
      assert saved_games_live |> element("[phx-click='unfocus']") |> render_click()
      assert saved_games_live |> render() =~ "Select a saved game by its dungeon on the left to learn more about it."
      refute saved_games_live |> element(".col-7") |> render() =~ save.dungeon_instance.dungeon.name
    end
  end

  describe "delete saved game" do
    setup [:create_user]

    test "clears the focused save", %{conn: conn, user: user, save: save} do
      {:ok, saved_games_live, _html} =
        live_isolated(conn, SavedGamesLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert saved_games_live |> element("[phx-click='focus#{save.dungeon_instance.dungeon.id}']") |> render_click()
      assert saved_games_live |> element("[phx-click='delete_save_#{save.id}']") |> render_click()
      assert saved_games_live |> render() =~ "Saved Games"
      refute saved_games_live |> render() =~ "phx-click='delete_save_#{save.id}"
    end
  end
end

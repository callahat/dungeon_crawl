defmodule DungeonCrawlWeb.DungeonLiveTest do
  use DungeonCrawlWeb.ConnCase

  import Phoenix.LiveViewTest
  import DungeonCrawl.GamesFixtures

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons.Metadata.{FavoriteDungeon, PinnedDungeon}

  alias DungeonCrawlWeb.DungeonLive

  @filters %{name: "", favorite: false, unplayed: false, not_won: false}

  defp create_user(_) do
    user = insert_user(%{username: "CSwaggins"})
    {:ok, user: user}
  end

  defp create_admin(_) do
    user = insert_user(%{username: "CSwaggins", is_admin: true})
    {:ok, user: user}
  end

  describe "list for anonymous user" do
    test "lists dungeons", %{conn: conn} do
      dungeon = insert_dungeon()

      {:ok, _dungeon_live, html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => "asdf", "controller_csrf" => "csrf"})

      assert html =~ "focus#{ dungeon.id }"
      assert html =~ dungeon.name
      # shouldn't see stars nor option to pin
      refute html =~ "fa fa-star"
      refute html =~ "fa fa-circle"
    end
  end

  describe "list for signed in user" do
    setup [:create_user]

    test "lists dungeons", %{conn: conn, user: user} do
      dungeon = insert_dungeon(%{id: 2, line_identifier: 1})

      {:ok, dungeon_live, html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert html =~ "focus#{ dungeon.id }"
      assert html =~ dungeon.name
      assert html =~ "fa fa-star"
      refute html =~ "fa fa-circle"

      # favoriting
      assert dungeon_live |> render() =~ "favorite_#{ dungeon.line_identifier }"
      assert dungeon_live |> element(".fa.fa-star-o") |> render_click()
      refute dungeon_live |> render() =~ "\"fa fa-star-o\""

      assert Repo.get_by(FavoriteDungeon,
               %{line_identifier: dungeon.line_identifier, user_id_hash: user.user_id_hash})

      # unfavoriting
      assert dungeon_live |> render() =~ "unfavorite_#{ dungeon.line_identifier }"
      assert dungeon_live |> element(".fa.fa-star") |> render_click()
      refute dungeon_live |> render() =~ "\"fa fa-star\""

      refute Repo.get_by(FavoriteDungeon,
               %{line_identifier: dungeon.line_identifier, user_id_hash: user.user_id_hash})
    end
  end

  # doesn't really do anything special other than show the user id, which right now will only
  describe "list for an admin" do
    setup [:create_admin]

    test "lists exports", %{conn: conn, user: user} do
      dungeon = insert_dungeon(%{id: 2, line_identifier: 1})
      insert_dungeon(%{id: 10, line_identifier: 3})

      {:ok, dungeon_live, html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert html =~ "focus#{ dungeon.id }"
      assert html =~ dungeon.name
      assert html =~ "fa fa-star"
      assert html =~ "fa fa-circle"

      # admins can also favorite like a standard user

      # favoriting
      assert dungeon_live |> render() =~ "favorite_#{ dungeon.line_identifier }"
      assert dungeon_live |> element("[phx-click='favorite_#{ dungeon.line_identifier }']") |> render_click()
      refute dungeon_live |> render() =~ "phx-click=\"favorite_#{ dungeon.line_identifier }\""

      assert Repo.get_by(FavoriteDungeon,
               %{line_identifier: dungeon.line_identifier, user_id_hash: user.user_id_hash})

      # unfavoriting
      assert dungeon_live |> render() =~ "unfavorite_#{ dungeon.line_identifier }"
      assert dungeon_live |> element("[phx-click='unfavorite_#{ dungeon.line_identifier }']") |> render_click()
      refute dungeon_live |> render() =~ "phx-click=\"unfavorite_#{ dungeon.line_identifier }\""

      refute Repo.get_by(FavoriteDungeon,
               %{line_identifier: dungeon.line_identifier, user_id_hash: user.user_id_hash})

      # Admins can pin dungeons on the list to make them rise to the top for all users

      # pinning
      assert dungeon_live |> render() =~ "pin_#{ dungeon.line_identifier }"
      assert dungeon_live |> element("[phx-click='pin_#{ dungeon.line_identifier }']") |> render_click()
      refute dungeon_live |> render() =~ "phx-click=\"pin_#{ dungeon.line_identifier }\""

      assert Repo.get_by(PinnedDungeon, %{line_identifier: dungeon.line_identifier})

      # unpinning
      assert dungeon_live |> render() =~ "unpin_#{ dungeon.line_identifier }"
      assert dungeon_live |> element("[phx-click='unpin_#{ dungeon.line_identifier }']") |> render_click()
      refute dungeon_live |> render() =~ "phx-click=\"unpin_#{ dungeon.line_identifier }\""

      refute Repo.get_by(PinnedDungeon, %{line_identifier: dungeon.line_identifier})
    end
  end

  describe "search dungeons" do
    setup [:create_user]

    test "no dungeons to search", %{conn: conn, user: user} do
      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      refute dungeon_live |> has_element?(".sidebar-scrollable-dungeon-list li.nav-item")

      assert dungeon_live
             |> form("#search-form", search: %{name: "Main"})
             |> render_change()

      refute dungeon_live |> has_element?(".sidebar-scrollable-dungeon-list li.nav-item")
    end

    test "searching on multiple things", %{conn: conn, user: user} do
      # more thorough coverage done in dungeons_test file
      dungeon1 = insert_dungeon(%{name: "One Dungeon"})
      dungeon2 = insert_dungeon(%{name: "Two Dungeon"})

      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert dungeon_live |> render() =~ dungeon1.name
      assert dungeon_live |> render() =~ dungeon2.name

      assert dungeon_live
             |> form("#search-form", search: %{@filters | name: "Two"})
             |> render_change()

      refute dungeon_live |> render() =~ dungeon1.name
      assert dungeon_live |> render() =~ dungeon2.name

      assert dungeon_live
             |> form("#search-form", search: %{@filters | name: "Two", favorite: true})
             |> render_change()

      refute dungeon_live |> render() =~ dungeon1.name
      refute dungeon_live |> render() =~ dungeon2.name

      # cleared filters
      assert dungeon_live
             |> form("#search-form", search: @filters)
             |> render_change()

      assert dungeon_live |> render() =~ dungeon1.name
      assert dungeon_live |> render() =~ dungeon2.name
    end
  end

  describe "focus dungeon" do
    test "displays information about the dungeon in the right pane", %{conn: conn} do
      dungeon = insert_dungeon(%{id: 2, line_identifier: 1, name: "Dungeon One"})
      insert_dungeon(%{id: 10, line_identifier: 3, name: "Dungeon Two"})

      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => "asdf", "controller_csrf" => "csrf"})

      assert dungeon_live |> render() =~ "focus#{ dungeon.id }"
      assert dungeon_live |> element("[phx-click='focus#{dungeon.id}']") |> render_click()
      refute dungeon_live |> render() =~ "Select a dungeon on the left to learn more about it"
      assert dungeon_live |> element(".col-7") |> render() =~ dungeon.name

      # focus will be retained on filtering when the dungeon is among the filtered list
      assert dungeon_live
             |> form("#search-form", search: %{ @filters | name: dungeon.name})
             |> render_change()
      assert dungeon_live |> element(".col-7") |> render() =~ dungeon.name

      # focus lost on filtering when the dungeon is not among the filtered list
      assert dungeon_live
             |> form("#search-form", search: %{ @filters | name: "whargarbl"})
             |> render_change()
      refute dungeon_live |> element(".col-7") |> render() =~ dungeon.name
    end
  end

  describe "unfocus dungeon" do
    test "clears the focused dungeon", %{conn: conn} do
      dungeon = insert_dungeon(%{id: 2, line_identifier: 1})
      insert_dungeon(%{id: 10, line_identifier: 3})

      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => "asdf", "controller_csrf" => "csrf"})

      assert dungeon_live |> element("[phx-click='focus#{dungeon.id}']") |> render_click()

      assert dungeon_live |> render() =~ "unfocus"
      assert dungeon_live |> element("[phx-click='unfocus']") |> render_click()
      assert dungeon_live |> render() =~ "Select a dungeon on the left to learn more about it"
      refute dungeon_live |> element(".col-7") |> render() =~ dungeon.name
    end
  end

  describe "delete saved game" do
    setup [:create_user]

    test "clears the focused save", %{conn: conn, user: user} do
      save = save_fixture(%{user_id_hash: user.user_id_hash})
             |> Repo.preload(dungeon_instance: :dungeon)

      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash, "controller_csrf" => "csrf"})

      assert dungeon_live |> element(".fa.fa-floppy-o") |> has_element?()
      assert dungeon_live |> element("[phx-click='focus#{save.dungeon_instance.dungeon.id}']") |> render_click()
      assert dungeon_live |> render() =~ "Saved Games"
      assert dungeon_live |> element("[phx-click='delete_save_#{save.id}']") |> render_click()
      refute dungeon_live |> element("[phx-click='delete_save_#{save.id}']") |> has_element?()
      # also removes the floppy icon since there are no more saves for the user for this dungeon
      refute dungeon_live |> element(".fa.fa-floppy-o") |> has_element?()
    end
  end
end

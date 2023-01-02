defmodule DungeonCrawlWeb.DungeonLiveTest do
  use DungeonCrawlWeb.ConnCase

  import Phoenix.LiveViewTest

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeons.Metadata
  alias DungeonCrawl.Dungeons.Metadata.{FavoriteDungeon, PinnedDungeon}
  alias DungeonCrawl.Scores

  alias DungeonCrawlWeb.DungeonLive

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
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => "asdf"})

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
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash})

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
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash})

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
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash})

      refute dungeon_live |> has_element?(".sidebar-scrollable-dungeon-list li")

      assert dungeon_live
             |> form("#search-form", search: %{name: "Main"})
             |> render_change()

      refute dungeon_live |> has_element?(".sidebar-scrollable-dungeon-list li")
    end

    test "searching on multiple things", %{conn: conn, user: user} do
      filters = %{name: "", favorite: false, unplayed: false, not_won: false}

      dungeon1 = insert_dungeon(%{name: "One Favorite"})
      dungeon2 = insert_dungeon(%{name: "Two Pinned"})
      _dungeon3 = insert_dungeon(%{name: "Three Not Played"})
      dungeon4 = insert_dungeon(%{name: "Four Not Won"})

      Metadata.pin(dungeon2)
      Metadata.favorite(dungeon1, user)

      Scores.create_score(%{dungeon_id: dungeon1.id, user_id_hash: user.user_id_hash, score: 9, victory: true})
      Scores.create_score(%{dungeon_id: dungeon2.id, user_id_hash: user.user_id_hash, score: 4, victory: true})
      Scores.create_score(%{dungeon_id: dungeon4.id, user_id_hash: user.user_id_hash, score: 0, victory: false})

      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => user.user_id_hash})

      assert dungeon_live |> render() =~ "One Favorite"
      assert dungeon_live |> render() =~ "Two Pinned"
      assert dungeon_live |> render() =~ "Three Not Played"
      assert dungeon_live |> render() =~ "Four Not Won"

      assert dungeon_live
             |> form("#search-form", search: %{ filters | name: "Two", favorite: true})
             |> render_change()

      refute dungeon_live |> render() =~ "One Favorite"
      refute dungeon_live |> render() =~ "Two Pinned"
      refute dungeon_live |> render() =~ "Three Not Played"
      refute dungeon_live |> render() =~ "Four Not Won"

      assert dungeon_live
             |> form("#search-form", search: %{filters | favorite: true})
             |> render_change()

      assert dungeon_live |> render() =~ "One Favorite"
      refute dungeon_live |> render() =~ "Two Pinned"
      refute dungeon_live |> render() =~ "Three Not Played"
      refute dungeon_live |> render() =~ "Four Not Won"

      assert dungeon_live
             |> form("#search-form", search: %{filters | unplayed: true})
             |> render_change()

      refute dungeon_live |> render() =~ "One Favorite"
      refute dungeon_live |> render() =~ "Two Pinned"
      assert dungeon_live |> render() =~ "Three Not Played"
      refute dungeon_live |> render() =~ "Four Not Won"

      assert dungeon_live
             |> form("#search-form", search: %{filters | name: "Not", not_won: true})
             |> render_change()

      refute dungeon_live |> render() =~ "One Favorite"
      refute dungeon_live |> render() =~ "Two Pinned"
      assert dungeon_live |> render() =~ "Three Not Played"
      assert dungeon_live |> render() =~ "Four Not Won"

      assert dungeon_live
             |> form("#search-form", search: %{filters | name: "Not"})
             |> render_change()

      refute dungeon_live |> render() =~ "One Favorite"
      refute dungeon_live |> render() =~ "Two Pinned"
      assert dungeon_live |> render() =~ "Three Not Played"
      assert dungeon_live |> render() =~ "Four Not Won"
    end
  end

  describe "focus dungeon" do
    test "displays information about the dungeon in the right pane", %{conn: conn} do
      dungeon = insert_dungeon(%{id: 2, line_identifier: 1})
      insert_dungeon(%{id: 10, line_identifier: 3})

      {:ok, dungeon_live, _html} =
        live_isolated(conn, DungeonLive, session: %{"user_id_hash" => "asdf"})

      assert dungeon_live |> render() =~ "focus#{ dungeon.id }"
      assert dungeon_live |> element("[phx-click='focus#{dungeon.id}']") |> render_click()
      refute dungeon_live |> render() =~ "Select a dungeon on the left to learn more about it"
      assert dungeon_live |> element(".col-7") |> render() =~ dungeon.name
    end
  end
end

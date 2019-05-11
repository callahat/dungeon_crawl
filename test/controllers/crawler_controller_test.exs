defmodule DungeonCrawl.CrawlerControllerTest do
  use DungeonCrawl.ConnCase

  import Plug.Conn, only: [assign: 3]

  setup %{conn: _conn} = config do
    if username = config[:login_as] do
      user = insert_user(%{username: username, is_admin: !config[:not_admin]})
      conn = assign(build_conn(), :current_user, user)
      {:ok, conn: conn, user: user}
    else
      conn = assign(build_conn(), :user_id_hash, "junkhash")
      {:ok, conn: conn}
    end
  end

  # show
  @tag login_as: "maxheadroom"
  test "show when no current dungeon", %{conn: conn} do
    conn = get conn, crawler_path(conn, :show)
    assert html_response(conn, 200) =~ "Not currently in any dungeon"
  end

  @tag login_as: "maxheadroom"
  test "show when current dungeon", %{conn: conn, user: user} do
    dungeon = insert_autogenerated_dungeon()
    insert_player_location(%{dungeon_id: dungeon.id, user_id_hash: user.user_id_hash})
    conn = get conn, crawler_path(conn, :show)
    refute html_response(conn, 200) =~ "Not currently in any dungeon"
    assert html_response(conn, 200) =~ "dungeon_preview"
  end

  test "show when current dungeon without signed in user", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon()
    insert_player_location(%{dungeon_id: dungeon.id, user_id_hash: conn.assigns[:user_id_hash]})
    conn = get conn, crawler_path(conn, :show)

    refute html_response(conn, 200) =~ "Not currently in any dungeon"
    assert html_response(conn, 200) =~ "dungeon_preview"
  end

  # create
  test "created redirects to show", %{conn: conn} do
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
  end

  test "player location is set", %{conn: conn} do
    conn = post conn, crawler_path(conn, :create)
    player_location = Repo.get_by(DungeonCrawl.PlayerLocation, %{user_id_hash: conn.assigns[:user_id_hash]})
    assert player_location
    assert player_location.dungeon_id
  end

  @tag login_as: "maxheadroom"
  test "does not create another dungeon if already crawling", %{conn: conn, user: user} do
    dungeon = insert_autogenerated_dungeon()
    insert_player_location(%{dungeon_id: dungeon.id, user_id_hash: user.user_id_hash})
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Already crawling dungeon"
  end

  # destroy
  @tag login_as: "maxheadroom"
  test "destroys current autogenerated dungeon", %{conn: conn, user: user} do
    dungeon = insert_autogenerated_dungeon()
    player_location = insert_player_location(%{dungeon_id: dungeon.id, user_id_hash: user.user_id_hash})
    conn = delete conn, crawler_path(conn, :destroy)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Dungeon cleared."
    refute Repo.get(DungeonCrawl.PlayerLocation, player_location.id)
    refute Repo.get(DungeonCrawl.Dungeon, dungeon.id)
  end
end

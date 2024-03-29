defmodule DungeonCrawlWeb.DungeonControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Equipment

  setup %{conn: _conn} = config do
    Equipment.Seeder.gun()

    insert_dungeon()

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
  test "index when no current dungeon", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :index)
    assert html_response(conn, 200)
  end

  @tag login_as: "maxheadroom"
  test "index or saved_games when current dungeon", %{conn: conn, user: user} do
    instance = insert_autogenerated_level_instance()
    dungeon = Repo.preload(instance, [dungeon: :dungeon]).dungeon.dungeon
    DungeonCrawl.Repo.update! Dungeon.changeset(dungeon, %{active: true, autogenerated: false})
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    updated_conn = get conn, dungeon_path(conn, :index)
    assert redirected_to(updated_conn) == crawler_path(updated_conn, :show)

    # saved_games
    updated_conn = get conn, dungeon_path(conn, :saved_games)
    assert redirected_to(updated_conn) == crawler_path(updated_conn, :show)
  end

  test "saved_games when not logged in", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :saved_games)
    assert redirected_to(conn) == dungeon_path(conn, :index)
  end

  @tag login_as: "maxheadroom"
  test "saved_games when logged in and not crawling", %{conn: conn} do
    conn = get conn, dungeon_path(conn, :saved_games)
    assert html_response(conn, 200)
  end
end

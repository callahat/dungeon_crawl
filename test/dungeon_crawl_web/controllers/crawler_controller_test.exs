defmodule DungeonCrawlWeb.CrawlerControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances

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
    instance = insert_autogenerated_dungeon_instance()
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = get conn, crawler_path(conn, :show)
    refute html_response(conn, 200) =~ "Not currently in any dungeon"
    assert html_response(conn, 200) =~ "dungeon_preview"
  end

  test "show when current dungeon without signed in user", %{conn: conn} do
    instance = insert_autogenerated_dungeon_instance()
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: conn.assigns[:user_id_hash]})
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
    player_location = Player.get_location!(conn.assigns[:user_id_hash]) |> Repo.preload(:map_tile)
    assert player_location
    assert player_location.map_tile
    assert player_location.map_tile.map_instance_id
  end

  @tag login_as: "maxheadroom"
  test "does not create another dungeon if already crawling", %{conn: conn, user: user} do
    instance = insert_autogenerated_dungeon_instance()
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Already crawling dungeon"
  end

  test "created does not generate a new solo dungeon if setting is off", %{conn: conn} do
    Admin.update_setting(%{autogen_solo_enabled: false})
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Generate and go solo is disabled"
    refute Player.get_location(conn.assigns[:user_id_hash])
  end

  # join
  test "join redirects to show", %{conn: conn} do
    instance = insert_autogenerated_dungeon_instance()
    conn = post conn, crawler_path(conn, :join), instance_id: instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
  end

  test "join redirects to show when starting a new instance", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon()
    conn = post conn, crawler_path(conn, :join), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
  end

  test "join does not start a new instance if max_instances is set and hit", %{conn: conn} do
    instance = insert_autogenerated_dungeon_instance()
    Admin.update_setting(%{max_instances: 1})
    conn = post conn, crawler_path(conn, :join), dungeon_id: instance.map_id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Dungeon has reached its limit on instances and cannot create another"
    refute Player.get_location(conn.assigns[:user_id_hash])
  end

  test "player location is set when joining", %{conn: conn} do
    instance = insert_autogenerated_dungeon_instance()
    conn = post conn, crawler_path(conn, :join), instance_id: instance.id
    player_location = Player.get_location!(conn.assigns[:user_id_hash]) |> Repo.preload(:map_tile)
    assert player_location
    assert player_location.map_tile
    assert player_location.map_tile.map_instance_id == instance.id
  end

  test "joining a dungeon creates new instance", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon()
    refute Repo.get_by(DungeonInstances.Map, %{map_id: dungeon.id})
    conn = post conn, crawler_path(conn, :join), dungeon_id: dungeon.id
    player_location = Player.get_location!(conn.assigns[:user_id_hash]) |> Repo.preload(map_tile: :dungeon)
    assert player_location
    assert player_location.map_tile
    assert player_location.map_tile.dungeon.map_id == dungeon.id
    assert Repo.get_by(DungeonInstances.Map, %{map_id: dungeon.id})
  end

  @tag login_as: "maxheadroom"
  test "does not join another dungeon instance if already crawling", %{conn: conn, user: user} do
    instance = insert_autogenerated_dungeon_instance()
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = post conn, crawler_path(conn, :join), instance_id: instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Already crawling dungeon"
  end

  test "join instance fails if dungeon is deleted", %{conn: conn} do
    instance = insert_autogenerated_dungeon_instance(%{deleted_at: NaiveDateTime.utc_now})
    conn = post conn, crawler_path(conn, :join), instance_id: instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "join instance fails if dungeon is not active", %{conn: conn} do
    instance = insert_autogenerated_dungeon_instance(%{active: false})
    conn = post conn, crawler_path(conn, :join), instance_id: instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "join dungeon fails if dungeon is deleted", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon(%{deleted_at: NaiveDateTime.utc_now})
    conn = post conn, crawler_path(conn, :join), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that dungeon"
  end

  test "join dungeon fails if dungeon is not active", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon(%{active: false})
    conn = post conn, crawler_path(conn, :join), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that dungeon"
  end

  @tag login_as: "maxheadroom"
  test "join dungeon allows the owner to join the inactive dungeon", %{conn: conn, user: user} do
    dungeon = insert_autogenerated_dungeon(%{active: false, user_id: user.id})
    conn = post conn, crawler_path(conn, :join), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    refute get_flash(conn, :error) == "Cannot join that dungeon"
  end

  # destroy
  @tag login_as: "maxheadroom"
  test "destroys current autogenerated dungeon", %{conn: conn, user: user} do
    instance = insert_autogenerated_dungeon_instance(%{active: true})
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = delete conn, crawler_path(conn, :destroy)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Dungeon cleared."
    refute Player.get_location(user.user_id_hash)
    refute DungeonInstances.get_map(instance.id)
    refute Dungeon.get_map(instance.map_id)
  end

  @tag login_as: "maxheadroom"
  test "does not destroy current instance if others are crawling", %{conn: conn, user: user} do
    instance = insert_stubbed_dungeon_instance(%{active: true})
    different_user = insert_user(%{username: "someoneelse", user_id_hash: "different dude"})
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})
    insert_player_location(%{map_instance_id: instance.id, user_id_hash: different_user.user_id_hash})
    # Seems that it might not be done propagating the instance_process, below sometimes fails with nil at the delete spot
    # TODO: remove the sleep, probably after most of the casts have been converted to calls
    :timer.sleep(100)
    conn = delete conn, crawler_path(conn, :destroy)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Dungeon cleared."
    refute Player.get_location(user.user_id_hash)
    assert Player.get_location(different_user.user_id_hash)
    assert DungeonInstances.get_map(instance.id)
    assert Dungeon.get_map(instance.map_id)
  end

  @tag login_as: "maxheadroom"
  test "redirects to the dungeon show if its inactive", %{conn: conn, user: user} do
    instance = insert_stubbed_dungeon_instance(%{active: false})
    location = insert_player_location(%{map_instance_id: instance.id, user_id_hash: user.user_id_hash})
    dungeon = Player.get_dungeon(location)
    conn = delete conn, crawler_path(conn, :destroy)
    assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
    assert get_flash(conn, :info) == "Dungeon cleared."
    refute Player.get_location(user.user_id_hash)
  end
end

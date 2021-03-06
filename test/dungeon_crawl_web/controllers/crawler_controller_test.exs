defmodule DungeonCrawlWeb.CrawlerControllerTest do
  use DungeonCrawlWeb.ConnCase

  import Plug.Conn, only: [assign: 3]

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.Dungeon
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
    instance = insert_autogenerated_level_instance()
    dungeon = Repo.preload(instance, [dungeon: :dungeon]).dungeon.dungeon
    DungeonCrawl.Repo.update! Dungeon.changeset(dungeon, %{active: true, autogenerated: false})
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = get conn, crawler_path(conn, :show)
    assert html_response(conn, 200) =~ "View Scores"
    refute html_response(conn, 200) =~ "Not currently in any dungeon"
    assert html_response(conn, 200) =~ "level_preview"
  end

  @tag login_as: "maxheadroom"
  test "show when current dungeon that does not score", %{conn: conn, user: user} do
    instance = insert_autogenerated_level_instance(%{state: "no_scoring: true"})
    dungeon = Repo.preload(instance, [dungeon: :dungeon]).dungeon.dungeon
    DungeonCrawl.Repo.update! Dungeon.changeset(dungeon, %{active: true, autogenerated: false})
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = get conn, crawler_path(conn, :show)
    refute html_response(conn, 200) =~ "View Scores"
    refute html_response(conn, 200) =~ "Not currently in any dungeon"
    assert html_response(conn, 200) =~ "level_preview"
  end

  test "show when current dungeon without signed in user", %{conn: conn} do
    instance = insert_autogenerated_level_instance()
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: conn.assigns[:user_id_hash]})
    conn = get conn, crawler_path(conn, :show)

    refute html_response(conn, 200) =~ "Not currently in any dungeon"
    assert html_response(conn, 200) =~ "level_preview"
  end

  # create
  test "created redirects to show", %{conn: conn} do
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
  end

  test "player location is set", %{conn: conn} do
    conn = post conn, crawler_path(conn, :create)
    player_location = Player.get_location!(conn.assigns[:user_id_hash]) |> Repo.preload(:tile)
    assert player_location
    assert player_location.tile
    assert player_location.tile.level_instance_id
  end

  @tag login_as: "maxheadroom"
  test "does not create another dungeon if already crawling", %{conn: conn, user: user} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    insert_player_location(%{dungeon_instance_id: dungeon_instance.id, level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Already crawling dungeon"
  end

  test "created does not generate a new solo dungeon if setting is off", %{conn: conn} do
    Admin.update_setting(%{autogen_solo_enabled: false})
    conn = post conn, crawler_path(conn, :create)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Generate and go solo is disabled"
    refute Player.get_location(conn.assigns[:user_id_hash])
  end

  # avatar
  test "avatar with anonymous displays the form", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert html_response(conn, 200) =~ "Customize Avatar"
  end

  test "avatar with an unregistered user who has already filled the form uses the previous avatar", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    conn = conn
           |> Plug.Test.init_test_session(%{})
           |> Plug.Conn.put_session(:user_avatar, %{color: "red", background_color: "gray", name: "nom"})
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
  end

  @tag login_as: "maxheadroom"
  test "avatar with a user uses their configured avatar", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert %{"color" => _, "background_color" => _, "name" => _} = conn.assigns[:user]
  end

  # validate_avatar
  test "validate_avatar returns to the form when colors match", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    expected_user = %{"color" => "red", "background_color" => "red"}
    conn = post conn, crawler_path(conn, :validate_avatar), dungeon_instance_id: dungeon_instance.id, user: expected_user
    assert html_response(conn, 200) =~ "Customize Avatar"
    assert get_flash(conn, :error) == "Color and Background Color must be different"
  end

  test "validate_avatar redirects to show when avatar valid", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    expected_user = %{"color" => "red", "background_color" => "gray", "name" => "name"}
    conn = post conn, crawler_path(conn, :validate_avatar), dungeon_instance_id: dungeon_instance.id, user: expected_user
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert ^expected_user = conn.assigns[:user]
    assert ^expected_user = Plug.Conn.get_session(conn, :user_avatar)
  end

  # join via avatar path
  @tag login_as: "maxheadroom"
  test "avatar join does not start a new instance if max_instances is set and hit", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    Admin.update_setting(%{max_instances: 1})
    conn = post conn, crawler_path(conn, :avatar), dungeon_id: dungeon_instance.dungeon_id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Dungeon has reached its limit on instances and cannot create another"
    refute Player.get_location(conn.assigns[:user_id_hash])
  end

  @tag login_as: "maxheadroom"
  test "player location is set when joining", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    player_location = Player.get_location!(conn.assigns[:user_id_hash]) |> Repo.preload(:tile)
    assert player_location
    assert player_location.tile
    assert player_location.tile.level_instance_id == instance.id
  end

  @tag login_as: "maxheadroom"
  test "avatar joining a dungeon creates new instance", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon()
    level = Repo.preload(dungeon, :levels).levels |> Enum.at(0)
    refute Repo.get_by(DungeonInstances.Dungeon, %{dungeon_id: dungeon.id})
    conn = post conn, crawler_path(conn, :avatar), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    player_location = Player.get_location!(conn.assigns[:user_id_hash]) |> Repo.preload(tile: :level)
    assert player_location
    assert player_location.tile
    assert player_location.tile.level.level_id == level.id
    assert Repo.get_by(DungeonInstances.Dungeon, %{dungeon_id: dungeon.id})
  end

  @tag login_as: "maxheadroom"
  test "does not join another dungeon instance if already crawling", %{conn: conn, user: user} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Already crawling dungeon"
  end

  test "avatar join instance fails if dungeon is deleted", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance(%{deleted_at: NaiveDateTime.utc_now})
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "avatar join instance fails if dungeon is not active", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance(%{active: false})
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "avatar join instance fails if dungeon is private", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance(%{is_private: true})
    conn = post conn, crawler_path(conn, :avatar), dungeon_instance_id: dungeon_instance.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "avatar join dungeon fails if dungeon is deleted", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon(%{deleted_at: NaiveDateTime.utc_now})
    conn = post conn, crawler_path(conn, :avatar), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that dungeon"
  end

  test "avatar join dungeon fails if dungeon is not active", %{conn: conn} do
    dungeon = insert_autogenerated_dungeon(%{active: false})
    conn = post conn, crawler_path(conn, :avatar), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that dungeon"
  end

  @tag login_as: "maxheadroom"
  test "avatar join dungeon allows the owner to join the inactive dungeon", %{conn: conn, user: user} do
    dungeon = insert_autogenerated_dungeon(%{active: false, user_id: user.id})
    conn = post conn, crawler_path(conn, :avatar), dungeon_id: dungeon.id
    assert redirected_to(conn) == crawler_path(conn, :show)
    refute get_flash(conn, :error) == "Cannot join that dungeon"
  end

  # invited
  test "invite into a dungeon instance when anonymous yields the avatar form", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    DungeonCrawl.Repo.update! DungeonInstances.Dungeon.changeset(dungeon_instance, %{autogenerated: false})
    conn = get conn, crawler_path(conn, :invite, dungeon_instance.id, dungeon_instance.passcode)
    assert html_response(conn, 200) =~ "Customize Avatar"
  end

  @tag login_as: "maxheadroom"
  test "invite into a dungeon instance", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    DungeonCrawl.Repo.update! DungeonInstances.Dungeon.changeset(dungeon_instance, %{autogenerated: false})
    conn = get conn, crawler_path(conn, :invite, dungeon_instance.id, dungeon_instance.passcode)
    assert redirected_to(conn) == crawler_path(conn, :show)
    refute get_flash(conn, :error)
  end

  test "invite fails if the instance does not exist", %{conn: conn} do
    conn = get conn, crawler_path(conn, :invite, 12345, "ABC123")
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "invite fails if the passcode is wrong", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    DungeonCrawl.Repo.update DungeonInstances.Dungeon.changeset(dungeon_instance, %{autogenerated: false})
    conn = get conn, crawler_path(conn, :invite, dungeon_instance.id, dungeon_instance.passcode <> "XXX")
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  test "invite fails if dungeon actually is autogenerated", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    conn = get conn, crawler_path(conn, :invite, dungeon_instance.id, dungeon_instance.passcode)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :error) == "Cannot join that instance"
  end

  # validate_invite is basically same as validate_avatar
  test "validate_invite returns to the form when colors match", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    DungeonCrawl.Repo.update DungeonInstances.Dungeon.changeset(dungeon_instance, %{autogenerated: false})
    expected_user = %{"color" => "red", "background_color" => "red"}
    conn = post conn, crawler_path(conn, :validate_invite, dungeon_instance.id, dungeon_instance.passcode), user: expected_user
    assert html_response(conn, 200) =~ "Customize Avatar"
    assert get_flash(conn, :error) == "Color and Background Color must be different"
  end

  test "validate_invite redirects to show when avatar valid", %{conn: conn} do
    dungeon_instance = insert_autogenerated_dungeon_instance()
    DungeonCrawl.Repo.update DungeonInstances.Dungeon.changeset(dungeon_instance, %{autogenerated: false})
    expected_user = %{"color" => "red", "background_color" => "gray", "name" => "name"}
    conn = post conn, crawler_path(conn, :validate_invite, dungeon_instance.id, dungeon_instance.passcode), user: expected_user
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert ^expected_user = conn.assigns[:user]
    assert ^expected_user = Plug.Conn.get_session(conn, :user_avatar)
  end

  # destroy
  @tag login_as: "maxheadroom"
  test "destroys and redirects to the scoreboards when score_id is given", %{conn: conn, user: user} do
    dungeon_instance = insert_stubbed_dungeon_instance(%{active: true})
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash, row: 2, z_index: 1})

    dungeon_id = dungeon_instance.dungeon_id
    score_id = insert_score(dungeon_id).id

    conn = delete conn, crawler_path(conn, :destroy, %{dungeon_id: dungeon_id, score_id: score_id})
    assert redirected_to(conn) == score_path(conn, :index, %{dungeon_id: dungeon_id, score_id: score_id})

    refute Player.get_location(user.user_id_hash)
    assert DungeonInstances.get_dungeon(dungeon_instance.id)
    assert Dungeons.get_level(instance.level_id)
  end

  @tag login_as: "maxheadroom"
  test "destroy redirects to crawler list when dungeon active", %{conn: conn, user: user} do
    dungeon_instance = insert_autogenerated_dungeon_instance(%{active: true})
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    conn = delete conn, crawler_path(conn, :destroy)
    assert redirected_to(conn) == crawler_path(conn, :show)
    assert get_flash(conn, :info) == "Dungeon cleared."
    refute Player.get_location(user.user_id_hash)
    assert DungeonInstances.get_dungeon(dungeon_instance.id)
    assert Dungeons.get_level(instance.level_id)
  end

  @tag login_as: "maxheadroom"
  test "destroy redirects to the dungeon show if its inactive", %{conn: conn, user: user} do
    dungeon_instance = insert_stubbed_dungeon_instance(%{active: false})
    instance = Repo.preload(dungeon_instance, :levels).levels |> Enum.at(0)
    location = insert_player_location(%{level_instance_id: instance.id, user_id_hash: user.user_id_hash})
    dungeon = Player.get_dungeon(location)
    conn = delete conn, crawler_path(conn, :destroy)
    assert redirected_to(conn) == dungeon_path(conn, :show, dungeon)
    assert get_flash(conn, :info) == "Dungeon cleared."
    refute Player.get_location(user.user_id_hash)
  end
end

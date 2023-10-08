defmodule DungeonCrawlWeb.CrawlerController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Account
  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Admin
  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonGeneration.InfiniteDungeon
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.DungeonProcesses.{DungeonRegistry, DungeonProcess, Registrar, LevelProcess}
  alias DungeonCrawl.Games

  import DungeonCrawlWeb.Crawler, only: [
    join_and_broadcast: 4,
    leave_and_broadcast: 1,
    save_and_broadcast: 2,
    save_and_broadcast: 3,
    load_and_broadcast: 2,
  ]

  plug :set_sidebar_col
  plug :assign_player_location
  plug :validate_crawling when action in [:show, :destroy]
  plug :validate_not_crawling  when action in [:create, :avatar, :validate_avatar, :invite, :validate_invite, :load]
  plug :validate_passcode when action in [:invite, :validate_invite]
  plug :validate_active_or_owner when action in [:avatar, :validate_avatar]
  plug :validate_autogen_solo_enabled when action in [:create]
  plug :validate_instance_limit when action in [:invite, :avatar, :validate_avatar]
  plug :validate_saveable when action in [:save, :save_and_quit]

  def show(conn, _opts) do
    # TODO: eventually have this get the location and other details from the level/dungeon process instead of DB which may have stale info
    player_location = conn.assigns[:player_location]

    dungeon = Repo.preload(player_location, [tile: [level: :dungeon]]).tile.level.dungeon
    dungeon = Repo.preload(dungeon, :dungeon)

    scorable = _scorable_dungeon(dungeon)

    saveable = !!(dungeon.dungeon.active &&
      dungeon.state["saveable"] &&
      conn.assigns.current_user)

    {:ok, instance_process} = Registrar.instance_process(player_location.tile.level)
    level = Map.put(LevelProcess.get_state(instance_process), :id, player_location.tile.level.id)
    player_tile = LevelProcess.get_tile(instance_process, player_location.tile.id)
    {player_stats, level, player_coord_id} = {PlayerInstance.current_stats(player_location.user_id_hash), level, "#{player_tile.row}_#{player_tile.col}"}

    conn
    |> Plug.Conn.put_session(:saveable, saveable)
    |> render("show.html", player_location: player_location, player_stats: player_stats, dungeon: dungeon, scorable: scorable, level: level, player_coord_id: player_coord_id)
  end

  def _scorable_dungeon(nil), do: false
  def _scorable_dungeon(dungeon_instance) do
    with {:ok, dungeon_process} <- DungeonRegistry.lookup_or_create(DungeonInstanceRegistry, dungeon_instance.id) do
      DungeonProcess.scorable?(dungeon_process)
    else
      _ -> false
    end
  end

  def avatar(conn, params) do
    params = Map.take(params, ["dungeon_id", "dungeon_instance_id", "is_private", "passcode"])
    if user = (get_session(conn, :user_avatar) || Account.get_by_user_id_hash(conn.assigns[:user_id_hash])) do
      user = Map.to_list(user)
             |> Enum.map(fn {k, v} -> {to_string(k), v} end)
             |> Enum.into(%{})
             |> Map.take(["name", "color", "background_color"])
      conn
      |> assign(:user, user)
      |> join(params)
    else
      user = %{"name" => "AnonPlayer", "color" => %User{}.color, "background_color" => %User{}.background_color}
      action_path = action_path(conn, params)
      render(conn, "avatar.html", user: user, action_path: action_path)
    end
  end

  def validate_avatar(conn, %{"user" => user} = params) do
    if User.colors_match?(%{color: user["color"], background_color: user["background_color"]}) do
      params = Map.take(conn.query_params, ["dungeon_id", "dungeon_instance_id", "is_private", "passcode"])
               |> Map.merge(Map.take(params, ["dungeon_id", "dungeon_instance_id", "is_private", "passcode"]))
      action_path = action_path(conn, params)
      conn
      |> assign(:query_params, params)
      |> put_flash(:error, "Color and Background Color must be different")
      |> render("avatar.html", user: user, action_path: action_path)
    else
      conn
      |> put_session(:user_avatar, user)
      |> assign(:user, user)
      |> join(params)
    end
  end

  # create a dungeon for the autogenerated solo experience
  def create(conn, _opts) do
    dungeon = InfiniteDungeon.generate_initial_levels()

    conn
    |> assign(:dungeon, dungeon)
    |> join(%{})
  end

  def invite(conn, %{"dungeon_instance_id" => _di_id, "passcode" => _passcode} = params) do
    avatar(conn, params)
  end

  def validate_invite(conn, %{"user" => _user} = params) do
    validate_avatar(conn, params)
  end

  def save(conn, _opts) do
    location = Player.get_location(conn.assigns[:user_id_hash])

    save_and_broadcast(location, Plug.Conn.get_session(conn, :saveable), false)

    conn
    |> put_flash(:info, "Saved")
    |> redirect(to: Routes.crawler_path(conn, :show))
  end

  def save_and_quit(conn, _opts) do
    location = Player.get_location(conn.assigns[:user_id_hash])
    dungeon_id = Player.dungeon_id(location)

    save_and_broadcast(location, Plug.Conn.get_session(conn, :saveable))

    conn
    |> put_flash(:info, "Saved")
    |> Plug.Conn.put_session(:focus_dungeon_id, dungeon_id)
    |> redirect(to: Routes.dungeon_path(conn, :index))
  end

  def load(conn, %{"save_id" => save_id}) do
    case load_and_broadcast(save_id, conn.assigns[:user_id_hash]) do
      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: Routes.dungeon_path(conn, :index))

      tile ->
        conn
        |> Plug.Conn.put_session(:dungeon_instance_id, Repo.preload(tile, :level).level.dungeon_instance_id)
        |> redirect(to: Routes.crawler_path(conn, :show))
    end
  end

  def destroy(conn, %{"dungeon_id" => dungeon_id, "score_id" => score_id}) do
    location = Player.get_location(conn.assigns[:user_id_hash])

    leave_and_broadcast(location)

    Games.list_saved_games(%{user_id_hash: conn.assigns[:user_id_hash], dungeon_id: dungeon_id})
    |> Enum.each(fn save -> Games.delete_save(save) end)

    conn
    |> put_flash(:info, "Dungeon cleared.")
    |> redirect(to: Routes.score_path(conn, :index, %{dungeon_id: dungeon_id, score_id: score_id}))
  end

  def destroy(conn, _opts) do
    case Plug.Conn.get_session(conn, :saveable) do
      true ->
        conn
        |> put_flash(:error, "Can only save, or save and quit")
        |> redirect(to: Routes.crawler_path(conn, :show))

      _ ->
        location = Player.get_location(conn.assigns[:user_id_hash])
        dungeon_id = Player.dungeon_id(location)

        dungeon = Player.get_dungeon(location)
        post_leave_path = if dungeon.active || dungeon.autogenerated, do: Routes.dungeon_path(conn, :index), else: Routes.edit_dungeon_path(conn, :show, dungeon)

        leave_and_broadcast(location)

        conn
        |> put_flash(:info, "Dungeon cleared.")
        |> Plug.Conn.put_session(:focus_dungeon_id, dungeon_id)
        |> redirect(to: post_leave_path)
    end
  end

  defp assign_player_location(conn, _opts) do
    # TODO: get this from the instance?
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(tile: [:level])

    conn
    |> assign(:player_location, player_location)
  end

  defp validate_not_crawling(conn, _opts) do
    if conn.assigns.player_location == nil do
      conn
    else
      conn
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_crawling(conn, _opts) do
    if conn.assigns.player_location != nil do
      conn
    else
      conn
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp validate_passcode(%{params: %{"dungeon_instance_id" => di_id, "passcode" => passcode}} = conn, _opts) do
    dungeon_instance = DungeonInstances.get_dungeon(di_id)
    dungeon_instance = if dungeon_instance, do: Repo.preload(dungeon_instance, :dungeon), else: nil

    cond do
      is_nil(dungeon_instance) ||
          dungeon_instance.autogenerated ||
          dungeon_instance.dungeon.deleted_at ||
          dungeon_instance.passcode != passcode ->
        conn
        |> put_flash(:error, "Cannot join that instance")
        |> redirect(to: Routes.dungeon_path(conn, :index))
        |> halt()
      # todo: check for max players in instance -> cannot join, but ok to let them know the info is correct
      true ->
        conn
        |> assign(:dungeon, dungeon_instance)
    end
  end

  defp validate_active_or_owner(%{params: %{"dungeon_id" => dungeon_id}} = conn, _opts) do
    dungeon = Dungeons.get_dungeon(dungeon_id)

    if dungeon && !dungeon.deleted_at && (dungeon.active ||
        (conn.assigns.current_user && dungeon.user_id == conn.assigns.current_user.id)) do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:dungeon, dungeon)
    else
      conn
      |> put_flash(:error, "Cannot join that dungeon")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp validate_active_or_owner(%{params: %{"dungeon_instance_id" => di_id}} = conn, _opts) do
    with dungeon_instance when not is_nil(dungeon_instance) <- DungeonInstances.get_dungeon(di_id),
         dungeon_instance = Repo.preload(dungeon_instance, :dungeon),
         true <- !dungeon_instance.dungeon.deleted_at &&
           dungeon_instance.dungeon.active &&
           !dungeon_instance.is_private do
      conn
      |> assign(:instance, dungeon_instance)
    else
      _ ->
        conn
        |> put_flash(:error, "Cannot join that instance")
        |> redirect(to: Routes.dungeon_path(conn, :index))
        |> halt()
    end
  end

  defp validate_autogen_solo_enabled(conn, _opts) do
    if Admin.get_setting.autogen_solo_enabled do
      conn
    else
      conn
      |> put_flash(:error, "Generate and go solo is disabled")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end

  defp validate_instance_limit(%{params: %{"dungeon_id" => dungeon_id}} = conn, _opts) do
    if is_nil(Admin.get_setting.max_instances) or Dungeons.instance_count(dungeon_id) < Admin.get_setting.max_instances do
      conn
    else
      conn
      |> put_flash(:error, "Dungeon has reached its limit on instances and cannot create another")
      |> redirect(to: Routes.dungeon_path(conn, :index))
      |> halt()
    end
  end
  defp validate_instance_limit(conn, _opts), do: conn

  defp validate_saveable(conn, _opts) do
    case Plug.Conn.get_session(conn, :saveable) do
      true ->
        conn

      _ ->
        conn
        |> put_flash(:error, "Cannot save")
        |> redirect(to: Routes.crawler_path(conn, :show))
        |> halt()
    end
  end

  defp join(conn, params) do
    join_target = cond do
                    params["passcode"] -> :dungeon
                    params["dungeon_instance_id"] -> :instance
                    true -> :dungeon
                  end

    {di_id, _} = join_and_broadcast(conn.assigns[join_target], conn.assigns[:user_id_hash], conn.assigns[:user], !!params["is_private"])
    conn
    |> Plug.Conn.put_session(:dungeon_instance_id, di_id)
    |> redirect(to: Routes.crawler_path(conn, :show))
  end

  defp action_path(conn, params) do
    cond do
      params["passcode"] -> Routes.crawler_path(conn, :validate_invite, params["dungeon_instance_id"], params["passcode"], params)
      true -> Routes.crawler_path(conn, :validate_avatar, params)
    end
  end

  defp set_sidebar_col(conn, _opts) do
    conn
    |> assign(:sidebar_col, 3)
  end
end

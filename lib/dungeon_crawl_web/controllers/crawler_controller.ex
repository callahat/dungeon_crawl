defmodule DungeonCrawlWeb.CrawlerController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.Player, as: PlayerInstance
  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias Ecto.Multi

  import DungeonCrawlWeb.Crawler, only: [join_and_broadcast: 2, leave_and_broadcast: 1]

  plug :assign_player_location when action in [:show, :create, :join, :destroy]
  plug :validate_not_crawling  when action in [:create, :join]
  plug :validate_active_or_owner when action in [:join]
  plug :validate_autogen_solo_enabled when action in [:create]
  plug :validate_instance_limit when action in [:join]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || ConnectedRooms

  def show(conn, _opts) do
    player_location = conn.assigns[:player_location]

    map_sets = if player_location, do: [], else: Dungeon.list_active_map_sets_with_player_count()
                                           |> Enum.map(fn(%{map_set: map_set}) -> Repo.preload(map_set, [:dungeons, :locations, :map_set_instances]) end)

    player_stats = if player_location do
                     PlayerInstance.current_stats(player_location.user_id_hash)
                   else
                     %{}
                   end

    render(conn, "show.html", player_location: player_location, map_sets: map_sets, player_stats: player_stats)
  end

  def create(conn, _opts) do
    dungeon_attrs = (%{name: "Autogenerated", width: Admin.get_setting.autogen_width, height: Admin.get_setting.autogen_height})

    # TODO: revisit multi's and clean this up
    Multi.new
    |> Multi.run(:map_set, fn(_repo, %{}) ->
        Dungeon.generate_map_set(@dungeon_generator, %{name: "Autogenerated", autogenerated: true}, dungeon_attrs)
      end)
    |> Multi.run(:map_set_instance, fn(_repo, %{map_set: map_set}) ->
        DungeonInstances.create_map_set(map_set)
      end)
    |> Multi.run(:player_location, fn(_repo, %{map_set: map_set}) ->
        # TODO: change this to only use stuff from the entrances
        map_set_instance = Enum.at(Repo.preload(map_set, :map_set_instances).map_set_instances, 0)
        Player.create_location_on_spawnable_space(map_set_instance, conn.assigns[:user_id_hash])
      end)
    |> Repo.transaction
    |> case do
      {:ok, %{map_set: _map_set}} ->
        conn
        |> redirect(to: Routes.crawler_path(conn, :show))
    end
  end

  def join(conn, %{"map_set_instance_id" => _msi_id}) do
    join_and_broadcast(conn.assigns.instance, conn.assigns[:user_id_hash])

    conn
    |> redirect(to: Routes.crawler_path(conn, :show))
  end

  def join(conn, %{"map_set_id" => _map_set_id}) do
    join_and_broadcast(conn.assigns.map_set, conn.assigns[:user_id_hash])

    conn
    |> redirect(to: Routes.crawler_path(conn, :show))
  end

  def destroy(conn, _opts) do
    location = Player.get_location(conn.assigns[:user_id_hash])

    map_set = Player.get_map_set(location)
    post_leave_path = if map_set.active || map_set.autogenerated, do: Routes.crawler_path(conn, :show), else: Routes.dungeon_path(conn, :show, map_set)

    leave_and_broadcast(location)

    conn
    |> put_flash(:info, "Dungeon cleared.")
    |> redirect(to: post_leave_path)
  end

  defp assign_player_location(conn, _opts) do
    # TODO: get this from the instance?
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(map_tile: [:dungeon])

    conn
    |> assign(:player_location, player_location)
  end

  defp validate_not_crawling(conn, _opts) do
    if conn.assigns.player_location == nil do
      conn
    else
      conn
      |> put_flash(:info, "Already crawling dungeon")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_active_or_owner(%{params: %{"map_set_id" => map_set_id}} = conn, _opts) do
    map_set = Dungeon.get_map_set!(map_set_id)

    if !map_set.deleted_at && (map_set.active ||
                              (conn.assigns.current_user && map_set.user_id == conn.assigns.current_user.id)) do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:map_set, map_set)
    else
      conn
      |> put_flash(:error, "Cannot join that dungeon")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_active_or_owner(%{params: %{"map_set_instance_id" => msi_id}} = conn, _opts) do
    map_set_instance = Repo.preload(DungeonInstances.get_map_set!(msi_id), :map_set)

    if !map_set_instance.map_set.deleted_at && map_set_instance.map_set.active do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:instance, map_set_instance)
    else
      conn
      |> put_flash(:error, "Cannot join that instance")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_autogen_solo_enabled(conn, _opts) do
    if Admin.get_setting.autogen_solo_enabled do
      conn
    else
      conn
      |> put_flash(:error, "Generate and go solo is disabled")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_instance_limit(%{params: %{"map_set_id" => map_set_id}} = conn, _opts) do
    if is_nil(Admin.get_setting.max_instances) or Dungeon.instance_count(map_set_id) < Admin.get_setting.max_instances do
      conn
    else
      conn
      |> put_flash(:error, "Dungeon has reached its limit on instances and cannot create another")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end
  defp validate_instance_limit(conn, _opts), do: conn
end

defmodule DungeonCrawlWeb.CrawlerController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias DungeonCrawl.TileState
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

    dungeons = if player_location, do: [], else: Dungeon.list_active_dungeons_with_player_count()
    player_map_tile = if player_location do
                        {:ok, parsed_state} = TileState.Parser.parse(player_location.map_tile.state)
                        Map.put(player_location.map_tile, :parsed_state, parsed_state)
                      else
                        nil
                      end

    render(conn, "show.html", player_location: player_location, dungeons: dungeons, player_map_tile: player_map_tile)
  end

  def create(conn, _opts) do
    dungeon_attrs = (%{name: "Autogenerated", width: Admin.get_setting.autogen_width, height: Admin.get_setting.autogen_height})

    # TODO: revisit multi's and clean this up
    Multi.new
    |> Multi.run(:dungeon, fn(_repo, %{}) ->
        {:ok, run_results} = Dungeon.generate_map(@dungeon_generator, dungeon_attrs)
        {:ok, run_results[:dungeon]}
      end)
    |> Multi.run(:instance, fn(_repo, %{dungeon: dungeon}) ->
        {:ok, run_results} = DungeonInstances.create_map(dungeon)
        {:ok, run_results[:dungeon]}
      end)
    |> Multi.run(:player_location, fn(_repo, %{instance: instance}) ->
        Player.create_location_on_empty_space(instance, conn.assigns[:user_id_hash])
      end)
    |> Repo.transaction
    |> case do
      {:ok, %{dungeon: _dungeon}} ->
        conn
        |> redirect(to: Routes.crawler_path(conn, :show))
    end
  end

  def join(conn, %{"instance_id" => _instance_id}) do
    join_and_broadcast(conn.assigns.instance, conn.assigns[:user_id_hash])

    conn
    |> redirect(to: Routes.crawler_path(conn, :show))
  end

  def join(conn, %{"dungeon_id" => _dungeon_id}) do
    join_and_broadcast(conn.assigns.dungeon, conn.assigns[:user_id_hash])

    conn
    |> redirect(to: Routes.crawler_path(conn, :show))
  end

  def destroy(conn, _opts) do
    location = Player.get_location(conn.assigns[:user_id_hash])

    dungeon = Player.get_dungeon(location)
    post_leave_path = if dungeon.active || dungeon.autogenerated, do: Routes.crawler_path(conn, :show), else: Routes.dungeon_path(conn, :show, dungeon)

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

  defp validate_active_or_owner(%{params: %{"dungeon_id" => dungeon_id}} = conn, _opts) do
    dungeon = Dungeon.get_map!(dungeon_id)

    if !dungeon.deleted_at && (dungeon.active ||
                              (conn.assigns.current_user && dungeon.user_id == conn.assigns.current_user.id)) do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:dungeon, dungeon)
    else
      conn
      |> put_flash(:error, "Cannot join that dungeon")
      |> redirect(to: Routes.crawler_path(conn, :show))
      |> halt()
    end
  end

  defp validate_active_or_owner(%{params: %{"instance_id" => instance_id}} = conn, _opts) do
    instance = Repo.preload(DungeonInstances.get_map!(instance_id), :dungeon)

    if !instance.dungeon.deleted_at && instance.dungeon.active do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:instance, instance)
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

  defp validate_instance_limit(%{params: %{"dungeon_id" => dungeon_id}} = conn, _opts) do
    if is_nil(Admin.get_setting.max_instances) or Dungeon.instance_count(dungeon_id) < Admin.get_setting.max_instances do
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

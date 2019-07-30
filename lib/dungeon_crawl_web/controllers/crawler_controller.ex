defmodule DungeonCrawlWeb.CrawlerController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonGenerator
  alias Ecto.Multi

  plug :assign_player_location when action in [:show, :create, :join]
  plug :validate_not_crawling  when action in [:create, :join]
  plug :validate_active_or_owner when action in [:join]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || DungeonGenerator

#  def index(conn, _params) do
#    render(conn, "index.html", crawler: crawler)
#  end

  def show(conn, _opts) do
    player_location = conn.assigns[:player_location]

    dungeons = if player_location, do: [], else: Dungeon.list_active_dungeons_with_player_count()

    render(conn, "show.html", player_location: player_location, dungeons: dungeons)
  end

  def create(conn, _opts) do
    dungeon_attrs = (%{name: "Autogenerated", width: 80, height: 40})

    # TODO: revisit multi's and clean this up
    Multi.new
    |> Multi.run(:dungeon, fn(%{}) ->
        {:ok, run_results} = Dungeon.generate_map(@dungeon_generator, dungeon_attrs)
        {:ok, run_results[:dungeon]}
      end)
    |> Multi.run(:instance, fn(%{dungeon: dungeon}) ->
        {:ok, run_results} = DungeonInstances.create_map(dungeon)
        {:ok, run_results[:dungeon]}
      end)
    |> Multi.run(:player_location, fn(%{instance: instance}) ->
        Player.create_location_on_empty_space(instance, conn.assigns[:user_id_hash])
      end)
    |> Repo.transaction
    |> case do
      {:ok, %{dungeon: _dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: crawler_path(conn, :show))
    end
  end

  def join(conn, %{"instance_id" => _instance_id}) do
    Player.create_location_on_empty_space(conn.assigns.instance, conn.assigns[:user_id_hash])
    |> case do
      {:ok, location} ->
        _broadcast_join(Repo.preload(location, :map_tile))
        conn
        |> put_flash(:info, "Dungeon joined successfully.")
        |> redirect(to: crawler_path(conn, :show))
    end
  end

  def join(conn, %{"dungeon_id" => _dungeon_id}) do
    {:ok, run_results} = DungeonInstances.create_map(conn.assigns.dungeon)
    instance = run_results[:dungeon]

    Player.create_location_on_empty_space(instance, conn.assigns[:user_id_hash])
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Dungeon joined successfully.")
        |> redirect(to: crawler_path(conn, :show))
    end
  end

  defp _broadcast_join(location) do
    top = Repo.preload(DungeonInstances.get_map_tile(location.map_tile), :tile_template)
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
                                    "player_joined",
                                    %{row: top.row, col: top.col, tile: DungeonCrawlWeb.SharedView.tile_and_style(top.tile_template)})
  end

  def destroy(conn, _opts) do
    player_location = Player.get_location(conn.assigns[:user_id_hash])
    
    location = Player.delete_location!(player_location)

    _broadcast_leave(location)

    conn
    |> put_flash(:info, "Dungeon cleared.")
    |> redirect(to: crawler_path(conn, :show))
  end

  defp _broadcast_leave(location) do
    top = Repo.preload(DungeonInstances.get_map_tile(location.map_tile), :tile_template)
    tile = if top, do: DungeonCrawlWeb.SharedView.tile_and_style(top.tile_template), else: ""
    DungeonCrawlWeb.Endpoint.broadcast("dungeons:#{location.map_tile.map_instance_id}",
                                    "player_left",
                                    %{row: location.map_tile.row, col: location.map_tile.col, tile: tile})
  end

  defp assign_player_location(conn, _opts) do
    player_location = Player.get_location(conn.assigns[:user_id_hash])
                      |> Repo.preload(map_tile: [:dungeon, dungeon: [dungeon_map_tiles: :tile_template]])
    conn
    |> assign(:player_location, player_location)
  end

  defp validate_not_crawling(conn, _opts) do
    if conn.assigns.player_location == nil do
      conn
    else
      conn
      |> put_flash(:info, "Already crawling dungeon")
      |> redirect(to: crawler_path(conn, :show))
      |> halt()
    end
  end

  def validate_active_or_owner(%{params: %{"dungeon_id" => dungeon_id}} = conn, _opts) do
    dungeon = Dungeon.get_map!(dungeon_id)

    if !dungeon.deleted_at && (dungeon.active ||
                              (conn.assigns.current_user && dungeon.user_id == conn.assigns.current_user.id)) do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:dungeon, dungeon)
    else
      conn
      |> put_flash(:error, "Cannot join that dungeon")
      |> redirect(to: crawler_path(conn, :show))
      |> halt()
    end
  end

  def validate_active_or_owner(%{params: %{"instance_id" => instance_id}} = conn, _opts) do
    instance = Repo.preload(DungeonInstances.get_map!(instance_id), :dungeon)

    if !instance.dungeon.deleted_at && instance.dungeon.active do #|| conn.assigns.current_user.is_admin
      conn
      |> assign(:instance, instance)
    else
      conn
      |> put_flash(:error, "Cannot join that instance")
      |> redirect(to: crawler_path(conn, :show))
      |> halt()
    end
  end
end

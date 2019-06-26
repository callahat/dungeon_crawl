defmodule DungeonCrawlWeb.CrawlerController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonGenerator
  alias Ecto.Multi

  plug :assign_player_location when action in [:show, :create, :join]
  plug :validate_not_crawling  when action in [:create, :join]

  @dungeon_generator Application.get_env(:dungeon_crawl, :generator) || DungeonGenerator

#  def index(conn, _params) do
#    render(conn, "index.html", crawler: crawler)
#  end

  def show(conn, _opts) do
    player_location = conn.assigns[:player_location]

    dungeons = if player_location, do: [], else: Dungeon.list_dungeons_with_player_count(:not_autogenerated)

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
    |> Multi.run(:player_location, fn(%{instance: dungeon}) ->
        empty_floor = Repo.preload(dungeon, dungeon_map_tiles: :tile_template).dungeon_map_tiles
                      |> Enum.filter(fn(t) -> t.tile_template.character == "." end)
                      |> Enum.random
        # todo: move somewhere else
        player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()
        map_tile = Map.take(empty_floor, [:map_instance_id, :row, :col])
                   |> Map.merge(%{tile_template_id: player_tile_template.id, z_index: 1})
                   |> DungeonCrawl.DungeonInstances.create_map_tile!()

        result = Player.create_location(%{map_tile_instance_id: map_tile.id, user_id_hash: conn.assigns[:user_id_hash]})
        {:ok, result}
      end)
    |> Repo.transaction
    |> case do
      {:ok, %{dungeon: _dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: crawler_path(conn, :show))
    end
  end

  def join(conn, %{"instance_id" => instance_id}) do
    instance = DungeonInstances.get_map!(instance_id)
    empty_floor = Repo.preload(instance, dungeon_map_tiles: :tile_template).dungeon_map_tiles
                  |> Enum.filter(fn(t) -> t.tile_template.character == "." end)
                  |> Enum.random
        # todo: move somewhere else
        player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()
        map_tile = Map.take(empty_floor, [:map_instance_id, :row, :col])
                   |> Map.merge(%{tile_template_id: player_tile_template.id, z_index: 1})
                   |> DungeonCrawl.DungeonInstances.create_map_tile!()

    Player.create_location(%{map_tile_instance_id: map_tile.id, user_id_hash: conn.assigns[:user_id_hash]})
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Dungeon joined successfully.")
        |> redirect(to: crawler_path(conn, :show))
    end
  end

  def join(conn, %{"dungeon_id" => dungeon_id}) do
    dungeon = Dungeon.get_map!(dungeon_id)
    {:ok, run_results} = DungeonInstances.create_map(dungeon)
    instance = run_results[:dungeon]

    empty_floor = Repo.preload(instance, dungeon_map_tiles: :tile_template).dungeon_map_tiles
                  |> Enum.filter(fn(t) -> t.tile_template.character == "." end)
                  |> Enum.random
        # todo: move somewhere else
        player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()
        map_tile = Map.take(empty_floor, [:map_instance_id, :row, :col])
                   |> Map.merge(%{tile_template_id: player_tile_template.id, z_index: 1})
                   |> DungeonCrawl.DungeonInstances.create_map_tile!()

    Player.create_location(%{map_tile_instance_id: map_tile.id, user_id_hash: conn.assigns[:user_id_hash]})
    |> case do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Dungeon joined successfully.")
        |> redirect(to: crawler_path(conn, :show))
    end
  end

  def destroy(conn, _opts) do
    player_location = Player.get_location(conn.assigns[:user_id_hash])
    
    Player.delete_location!(player_location)

    conn
    |> put_flash(:info, "Dungeon cleared.")
    |> redirect(to: crawler_path(conn, :show))
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
end

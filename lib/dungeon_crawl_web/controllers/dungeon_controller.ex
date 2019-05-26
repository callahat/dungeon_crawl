defmodule DungeonCrawlWeb.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.Map
  alias DungeonCrawl.DungeonGenerator

  def index(conn, _params) do
    dungeons = Dungeon.list_dungeons()
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.change_map(%Map{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"map" => dungeon_params}) do
    case Dungeon.generate_map(DungeonGenerator, dungeon_params) do
      {:ok, %{dungeon: dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, changeset, _others} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    dungeon = Dungeon.get_map!(id) |> Repo.preload(:dungeon_map_tiles)
    dungeon_render = 
      dungeon.dungeon_map_tiles
      |> Enum.sort(fn(a,b) -> {a.row, a.col} < {b.row, b.col} end)
      |> Enum.map(fn(row) -> row.tile end)
      |> to_charlist
      |> Enum.chunk(dungeon.width) # TODO: replace this with something like dungeon.width if this ever is not hardcoded
      |> Enum.join("\n")

    render(conn, "show.html", dungeon: dungeon, dungeon_render: dungeon_render)
  end

  def delete(conn, %{"id" => id}) do
    dungeon = Dungeon.get_map!(id)

    Dungeon.delete_map!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: dungeon_path(conn, :index))
  end
end

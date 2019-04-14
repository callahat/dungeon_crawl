defmodule DungeonCrawl.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonMapTile
  alias DungeonCrawl.DungeonGenerator
  alias Ecto.Multi

  def index(conn, _params) do
    dungeons = Repo.all(Dungeon)
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.changeset(%Dungeon{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"dungeon" => dungeon_params}) do
    Multi.new
    |> Multi.insert(:dungeon, Dungeon.changeset(%Dungeon{}, dungeon_params))
    |> Multi.run(:dungeon_map_tiles, fn(%{dungeon: dungeon}) ->
        result = Repo.insert_all(DungeonMapTile, Dungeon.generate_dungeon_map_tiles(dungeon, DungeonGenerator))
        {:ok, result}
      end)
    |> Repo.transaction
    |> case do
      {:ok, %{dungeon: dungeon}} ->
        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, :dungeon, changeset, _others} ->
        render(conn, "new.html", changeset: changeset)
      # This probably won't happen; if :dungeon_map_tiles has a prolem insert_all, exception bubbles up
      {:error, op, _res, _others} ->
        conn
        |> put_flash(:error, "Something went wrong with '#{op}'")
        |> render("new.html", changeset: Dungeon.changeset(%Dungeon{}))
    end
  end

  def show(conn, %{"id" => id}) do
    dungeon = Repo.get!(Dungeon, id) |> Repo.preload(:dungeon_map_tiles)
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
    dungeon = Repo.get!(Dungeon, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(dungeon)

    conn
    |> put_flash(:info, "Dungeon deleted successfully.")
    |> redirect(to: dungeon_path(conn, :index))
  end
end

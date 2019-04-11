defmodule DungeonCrawl.DungeonController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.DungeonMapTile
  alias DungeonCrawl.DungeonGenerator

  def index(conn, _params) do
    dungeons = Repo.all(Dungeon)
    render(conn, "index.html", dungeons: dungeons)
  end

  def new(conn, _params) do
    changeset = Dungeon.changeset(%Dungeon{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"dungeon" => dungeon_params}) do
    changeset = Dungeon.changeset(%Dungeon{}, dungeon_params)

    case Repo.insert(changeset) do
      {:ok, dungeon} ->
        dungeon_map_tiles = Dungeon.generate_dungeon_map_tiles(dungeon, DungeonGenerator,Ecto.DateTime.autogenerate)

        Repo.insert_all(DungeonMapTile, dungeon_map_tiles)

        conn
        |> put_flash(:info, "Dungeon created successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    dungeon = Repo.get!(Dungeon, id) |> Repo.preload(:dungeon_map_tiles)
    dungeon_render = 
      dungeon.dungeon_map_tiles
      |> Enum.sort(fn(a,b) -> {a.row, a.col} < {b.row, b.col} end)
      |> Enum.map(fn(row) -> row.tile end)
      |> to_charlist
      |> Enum.chunk(80) # TODO: replace this with something like dungeon.width if this ever is not hardcoded
      |> Enum.join("\n")

    render(conn, "show.html", dungeon: dungeon, dungeon_render: dungeon_render)
  end

  def edit(conn, %{"id" => id}) do
    dungeon = Repo.get!(Dungeon, id)
    changeset = Dungeon.changeset(dungeon)
    render(conn, "edit.html", dungeon: dungeon, changeset: changeset)
  end

  def update(conn, %{"id" => id, "dungeon" => dungeon_params}) do
    dungeon = Repo.get!(Dungeon, id)
    changeset = Dungeon.changeset(dungeon, dungeon_params)

    case Repo.update(changeset) do
      {:ok, dungeon} ->
        conn
        |> put_flash(:info, "Dungeon updated successfully.")
        |> redirect(to: dungeon_path(conn, :show, dungeon))
      {:error, changeset} ->
        render(conn, "edit.html", dungeon: dungeon, changeset: changeset)
    end
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

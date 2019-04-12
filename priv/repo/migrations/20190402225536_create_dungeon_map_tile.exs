defmodule DungeonCrawl.Repo.Migrations.CreateDungeonMapTile do
  use Ecto.Migration

  def change do
    create table(:dungeon_map_tiles) do
      add :row, :integer
      add :col, :integer
      add :tile, :string
      add :dungeon_id, references(:dungeons, on_delete: :nothing)
    end
    create index(:dungeon_map_tiles, [:dungeon_id, :row, :col])

  end
end

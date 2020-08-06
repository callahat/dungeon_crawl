defmodule DungeonCrawl.Repo.Migrations.CreateSpawnLocations do
  use Ecto.Migration

  def change do
    create table(:spawn_locations) do
      add :row, :integer
      add :col, :integer
      add :dungeon_id, references(:dungeons, on_delete: :nothing)
    end

    create index(:spawn_locations, [:dungeon_id])
    create unique_index(:spawn_locations, [:dungeon_id, :row, :col], name: :spawn_locations_dungeon_id_row_col_index)
  end
end

defmodule DungeonCrawl.Repo.Migrations.RemoveCoordinateInfoFromPlayerLocation do
  use Ecto.Migration

  def up do
    alter table(:player_locations) do
      remove :row
      remove :col
      remove :dungeon_id
    end
  end

  def down do
    alter table(:player_locations) do
      add :row, :integer
      add :col, :integer
      add :dungeon_id, references(:dungeons, on_delete: :nothing)
    end
    create index(:player_locations, [:dungeon_id])
  end
end

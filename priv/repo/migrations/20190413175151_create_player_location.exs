defmodule DungeonCrawl.Repo.Migrations.CreatePlayerLocation do
  use Ecto.Migration

  def change do
    create table(:player_locations) do
      add :row, :integer
      add :col, :integer
      add :user_id_hash, :string
      add :dungeon_id, references(:dungeons, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing), null: true

      timestamps()
    end
    create index(:player_locations, [:dungeon_id])
    create index(:player_locations, [:user_id])
    create index(:player_locations, [:user_id_hash])

  end
end

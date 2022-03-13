defmodule DungeonCrawl.Repo.Migrations.CreateDungeonExports do
  use Ecto.Migration

  def change do
    create table(:dungeon_exports) do
      add :status, :integer
      add :data, :text
      add :dungeon_id, references(:dungeons, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:dungeon_exports, [:dungeon_id])
    create index(:dungeon_exports, [:user_id])
    create index(:dungeon_exports, [:status])
  end
end

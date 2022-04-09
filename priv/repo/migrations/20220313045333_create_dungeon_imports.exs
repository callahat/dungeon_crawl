defmodule DungeonCrawl.Repo.Migrations.CreateDungeonImports do
  use Ecto.Migration

  def change do
    create table(:dungeon_imports) do
      add :status, :integer
      add :data, :text
      add :line_identifier, :integer
      add :dungeon_id, references(:dungeons, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:dungeon_imports, [:dungeon_id])
    create index(:dungeon_imports, [:user_id])
    create index(:dungeon_imports, [:status])
  end
end

defmodule DungeonCrawl.Repo.Migrations.AddOwningUserIdToDungeon do
  use Ecto.Migration

  def change do
    alter table(:dungeons) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:dungeons, [:user_id])
  end
end

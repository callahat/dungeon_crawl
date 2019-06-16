defmodule DungeonCrawl.Repo.Migrations.RemoveUserIdFromPlayerLocation do
  use Ecto.Migration

  def up do
    alter table(:player_locations) do
      remove :user_id
    end
  end

  def down do
    alter table(:player_locations) do
      add :user_id, references(:users, on_delete: :nothing), null: true
    end
    create index(:player_locations, [:user_id])
  end
end

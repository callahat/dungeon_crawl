defmodule DungeonCrawl.Repo.Migrations.CreateSavedGames do
  use Ecto.Migration

  def change do
    create table(:saved_games) do
      add :user_id_hash, :string
      add :row, :integer
      add :col, :integer
      add :state, :string, size: 2048
      add :level_instance_id, references(:level_instances, on_delete: :restrict)

      timestamps()
    end

    create index(:saved_games, [:level_instance_id])
  end
end

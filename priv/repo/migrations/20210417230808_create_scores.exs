defmodule DungeonCrawl.Repo.Migrations.CreateScores do
  use Ecto.Migration

  def change do
    create table(:scores) do
      add :score, :integer
      add :steps, :integer
      add :duration, :time
      add :result, :string
      add :victory, :boolean, default: false, null: false
      add :map_set_id, references(:map_sets, on_delete: :nothing)
      add :user_id_hash, :string

      timestamps()
    end

    create index(:scores, [:map_set_id])
    create index(:scores, [:user_id_hash])
  end
end

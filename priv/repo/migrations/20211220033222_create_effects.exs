defmodule DungeonCrawl.Repo.Migrations.CreateEffects do
  use Ecto.Migration

  def change do
    create table(:effects) do
      add :name, :string, size: 32
      add :slug, :string, size: 45
      add :zzfx_params, :string, size: 120
      add :public, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:effects, [:user_id, :slug])
    create index(:effects, [:slug], unique: true)
  end
end

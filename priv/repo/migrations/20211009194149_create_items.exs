defmodule DungeonCrawl.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :name, :string, size: 32
      add :description, :string
      add :slug, :string
      add :script, :string, size: 2048
      add :public, :boolean, default: false, null: false
      add :weapon, :boolean, default: false, null: false
      add :consumable, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:items, [:slug])
  end
end

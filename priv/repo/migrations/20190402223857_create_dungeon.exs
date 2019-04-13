defmodule DungeonCrawl.Repo.Migrations.CreateDungeon do
  use Ecto.Migration

  def change do
    create table(:dungeons) do
      add :name, :string
      add :width, :integer
      add :height, :integer

      timestamps()
    end

  end
end

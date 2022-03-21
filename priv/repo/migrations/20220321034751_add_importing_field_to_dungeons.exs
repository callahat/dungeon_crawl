defmodule DungeonCrawl.Repo.Migrations.AddImportingFieldToDungeons do
  use Ecto.Migration

  def change do
    alter table(:dungeons) do
      add :importing, :boolean, default: false
    end
  end
end

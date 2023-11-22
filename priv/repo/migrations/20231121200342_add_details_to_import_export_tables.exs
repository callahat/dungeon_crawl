defmodule DungeonCrawl.Repo.Migrations.AddDetailsToImportExportTables do
  use Ecto.Migration

  def change do
    alter table(:dungeon_imports) do
      add :details, :text
    end
    alter table(:dungeon_exports) do
      add :details, :text
    end
  end
end

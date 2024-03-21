defmodule DungeonCrawl.Repo.Migrations.AddReportColumnToDungeonImports do
  use Ecto.Migration

  def change do
    alter table(:dungeon_imports) do
      add :log, :text
    end
  end
end

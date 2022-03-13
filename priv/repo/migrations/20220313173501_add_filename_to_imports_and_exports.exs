defmodule DungeonCrawl.Repo.Migrations.AddFilenameToImportsAndExports do
  use Ecto.Migration

  def change do
    alter table(:dungeon_exports) do
      add :file_name, :string, null: false
    end
    alter table(:dungeon_imports) do
      add :file_name, :string, null: false
    end
  end
end

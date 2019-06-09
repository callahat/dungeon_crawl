defmodule DungeonCrawl.Repo.Migrations.AddDeletedAtToTileTemplates do
  use Ecto.Migration

  def change do
    alter table(:tile_templates) do
      add :deleted_at, :naive_datetime
    end
    create index(:tile_templates, [:deleted_at])
  end
end

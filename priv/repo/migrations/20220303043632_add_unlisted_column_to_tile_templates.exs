defmodule DungeonCrawl.Repo.Migrations.AddUnlistedColumnToTileTemplates do
  use Ecto.Migration

  def change do
    alter table(:tile_templates) do
      add :unlisted, :boolean, default: false, null: false
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.CreateTileTemplateGroups do
  use Ecto.Migration

  def change do
    alter table(:tile_templates) do
      add :group_name, :string, size: 16
    end

    create index(:tile_templates, [:group_name])
  end
end

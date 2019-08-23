defmodule DungeonCrawl.Repo.Migrations.AddVersioningToTileTemplates do
  use Ecto.Migration

  def up do
    alter table(:tile_templates) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :version, :integer, default: 1
      add :active, :boolean
      add :public, :boolean
      add :previous_version_id, references(:tile_templates, on_delete: :delete_all)
    end

    create index(:tile_templates, [:user_id])
    create index(:tile_templates, [:active, :public])

    flush()

    execute "UPDATE tile_templates SET version = 1, active = true, public = true;"
  end

  def down do
    alter table(:tile_templates) do
      remove :user_id
      remove :version
      remove :active
      remove :public
      remove :previous_version_id
    end
  end
end

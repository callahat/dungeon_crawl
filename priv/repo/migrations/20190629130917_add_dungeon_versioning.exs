defmodule DungeonCrawl.Repo.Migrations.AddDungeonVersioning do
  use Ecto.Migration

  def up do
    alter table(:dungeons) do
      add :version, :integer, default: 1
      add :active, :boolean
      add :deleted_at, :naive_datetime
      add :previous_version_id, references(:dungeons, on_delete: :delete_all)
    end

    create index(:dungeons, [:deleted_at])
    create index(:dungeons, [:active])

    flush()

    execute "UPDATE dungeons SET version = 1, active = true;"
  end

  def down do
    alter table(:dungeons) do
      remove :version
      remove :active
      remove :deleted_at
      remove :previous_version_id
    end
  end
end

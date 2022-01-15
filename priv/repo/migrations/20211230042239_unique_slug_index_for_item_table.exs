defmodule DungeonCrawl.Repo.Migrations.UniqueSlugIndexForItemTable do
  use Ecto.Migration

  def up do
    drop index(:items, [:slug])

    create index(:items, [:user_id, :slug])
    create index(:items, [:slug], unique: true)
  end

  def down do
    drop index(:items, [:user_id, :slug])
    drop index(:items, [:slug])

    create index(:items, [:slug])
  end
end

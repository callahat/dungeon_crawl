defmodule DungeonCrawl.Repo.Migrations.CreateAssetImports do
  use Ecto.Migration

  def change do
    create table(:asset_imports) do
      add :type, :integer
      add :importing_slug, :string
      add :existing_slug, :string
      add :resolved_slug, :string
      add :action, :integer
      add :attributes, :map
      add :dungeon_import_id, references(:dungeon_imports, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:asset_imports, [:dungeon_import_id, :type, :importing_slug])
  end
end

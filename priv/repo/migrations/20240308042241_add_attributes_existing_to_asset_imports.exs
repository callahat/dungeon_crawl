defmodule DungeonCrawl.Repo.Migrations.AddAttributesExistingToAssetImports do
  use Ecto.Migration

  def change do
    alter table(:asset_imports) do
      add :existing_attributes, :map
    end
  end
end

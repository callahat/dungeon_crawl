defmodule DungeonCrawl.Repo.Migrations.AddDescriptionToMapSet do
  use Ecto.Migration

  def change do
    alter table(:map_sets) do
      add :description, :string, size: 1024
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.AddDefaultWidthHeightToMapSet do
  use Ecto.Migration

  def change do
    alter table(:map_sets) do
      add :default_map_width, :integer
      add :default_map_height, :integer
    end
  end
end

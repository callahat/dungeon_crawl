defmodule DungeonCrawl.Repo.Migrations.AddNameToMapTile do
  use Ecto.Migration

  def change do
    alter table(:dungeon_map_tiles) do
      add :name, :string, size: 32
    end
    alter table(:map_tile_instances) do
      add :name, :string, size: 32
    end
  end
end

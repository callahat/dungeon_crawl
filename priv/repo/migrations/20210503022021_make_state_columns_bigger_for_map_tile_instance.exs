defmodule DungeonCrawl.Repo.Migrations.MakeStateColumnsBiggerForMapTileInstance do
  use Ecto.Migration

  def up do
    alter table(:map_tile_instances) do
      modify :state, :string, size: 2048
    end
  end

  def down do
    alter table(:map_tile_instances) do
      modify :state, :string, size: 255
    end
  end
end

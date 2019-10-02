defmodule DungeonCrawl.Repo.Migrations.MakeScriptColumnBigger do
  use Ecto.Migration

  def up do
    alter table(:dungeon_map_tiles) do
      modify :script, :string, size: 2048
    end
    alter table(:map_tile_instances) do
      modify :script, :string, size: 2048
    end
    alter table(:tile_templates) do
      modify :script, :string, size: 2048
    end
  end

  def down do
    alter table(:dungeon_map_tiles) do
      modify :script, :string, size: 255
    end
    alter table(:map_tile_instances) do
      modify :script, :string, size: 255
    end
    alter table(:tile_templates) do
      modify :script, :string, size: 255
    end
  end
end

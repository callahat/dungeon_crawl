defmodule DungeonCrawl.Repo.Migrations.AddMapTileAnimationFields do
  use Ecto.Migration

  def change do
    alter table(:tile_templates) do
      add :animate_random, :boolean
      add :animate_colors, :string, size: 255
      add :animate_background_colors, :string, size: 255
      add :animate_characters, :string, size: 32
      add :animate_period, :integer
    end
    alter table(:dungeon_map_tiles) do
      add :animate_random, :boolean
      add :animate_colors, :string, size: 255
      add :animate_background_colors, :string, size: 255
      add :animate_characters, :string, size: 32
      add :animate_period, :integer
    end
    alter table(:map_tile_instances) do
      add :animate_random, :boolean
      add :animate_colors, :string, size: 255
      add :animate_background_colors, :string, size: 255
      add :animate_characters, :string, size: 32
      add :animate_period, :integer
    end
  end
end

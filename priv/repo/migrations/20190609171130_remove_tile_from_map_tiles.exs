defmodule DungeonCrawl.Repo.Migrations.RemoveTileFromMapTiles do
  use Ecto.Migration

  def up do
    alter table(:dungeon_map_tiles) do
      remove :tile
    end
  end
end

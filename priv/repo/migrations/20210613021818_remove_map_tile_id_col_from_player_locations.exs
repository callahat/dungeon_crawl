defmodule DungeonCrawl.Repo.Migrations.RemoveMapTileIdColFromPlayerLocations do
  use Ecto.Migration

  def up do
    alter table(:player_locations) do
      remove :map_tile_id
    end
  end

  def down do
    alter table(:player_locations) do
      add :map_tile_id, references(:tiles, on_delete: :delete_all, name: "player_locations_tile_id_fkey")
    end
  end
end

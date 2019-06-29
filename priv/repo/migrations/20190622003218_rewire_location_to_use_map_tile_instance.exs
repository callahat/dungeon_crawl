defmodule DungeonCrawl.Repo.Migrations.RewireLocationToUseMapTileInstance do
  use Ecto.Migration

  def change do
    alter table(:player_locations) do
      add :map_tile_instance_id, references(:map_tile_instances, on_delete: :delete_all)
    end

    create index(:player_locations, [:map_tile_instance_id])
  end
end

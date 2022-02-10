defmodule DungeonCrawl.Repo.Migrations.AddHeaderAndLocationIdToLevelInstances do
  use Ecto.Migration

  def change do
    alter table(:level_instances) do
      add :player_location_id, references(:player_locations, on_delete: :delete_all)
      add :level_header_id, references(:level_headers, on_delete: :delete_all)
    end

    create index(:level_instances, [:player_location_id])
    create index(:level_instances, [:level_header_id])
  end
end

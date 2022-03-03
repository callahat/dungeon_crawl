defmodule DungeonCrawl.Repo.Migrations.FixCascadeOnTilesLevelIdFkey do
  use Ecto.Migration

  def up do
    drop constraint(:tiles, :tiles_level_id_fkey)
    drop constraint(:spawn_locations, :spawn_locations_level_id_fkey)

    alter table(:tiles) do
      modify :level_id, references(:levels, on_delete: :delete_all)
    end
    alter table(:spawn_locations) do
      modify :level_id, references(:levels, on_delete: :delete_all)
    end
  end

  def down do
    drop constraint(:tiles, :tiles_level_id_fkey)
    drop constraint(:spawn_locations, :spawn_locations_level_id_fkey)

    alter table(:tiles) do
      modify :level_id, references(:levels)
    end
    alter table(:spawn_locations) do
      modify :level_id, references(:levels)
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.CreateMapTileInstances do
  use Ecto.Migration

  def change do
    create table(:map_tile_instances) do
      add :row, :integer
      add :col, :integer
      add :z_index, :integer
      add :map_instance_id, references(:map_instances, on_delete: :delete_all)
      add :tile_template_id, references(:tile_templates, on_delete: :delete_all)
    end

    create index(:map_tile_instances, [:map_instance_id])
    create index(:map_tile_instances, [:tile_template_id])
  end
end

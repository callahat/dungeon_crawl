defmodule DungeonCrawl.Repo.Migrations.CreateUniqueConstraintForLevelNumbers do
  use Ecto.Migration

  def change do
    create unique_index(:dungeons, [:map_set_id, :number], name: :dungeons_map_set_id_number_index)
    create unique_index(:map_instances, [:map_set_instance_id, :number], name: :map_instances_map_set_instance_id_number_index)
  end
end

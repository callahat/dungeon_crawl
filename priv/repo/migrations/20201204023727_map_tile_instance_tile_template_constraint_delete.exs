defmodule DungeonCrawl.Repo.Migrations.MapTileInstanceTileTemplateConstraintDelete do
  use Ecto.Migration

  def change do
    alter table(:map_tile_instances) do
      remove :tile_template_id, references(:map_instances, on_delete: :delete_all)
    end
  end
end

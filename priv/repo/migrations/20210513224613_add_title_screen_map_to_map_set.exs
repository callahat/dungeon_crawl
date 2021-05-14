defmodule DungeonCrawl.Repo.Migrations.AddTitleScreenMapToMapSet do
  use Ecto.Migration

  def change do
    alter table(:map_sets) do
      add :title_map_id, references(:dungeons, on_delete: :nilify_all), null: true
    end
  end
end

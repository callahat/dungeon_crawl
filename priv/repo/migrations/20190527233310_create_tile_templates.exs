defmodule DungeonCrawl.Repo.Migrations.CreateTileTemplates do
  use Ecto.Migration

  def change do
    create table(:tile_templates) do
      add :name, :string
      add :character, :string
      add :description, :string
      add :color, :string
      add :background_color, :string
      add :responders, :string

      timestamps()
    end

    # seed the basic tiles 

    alter table(:dungeon_map_tiles) do
      add :tile_template_id, references(:tile_templates, on_delete: :nothing)
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.AddSlugToTileTemplate do
  use Ecto.Migration

  alias DungeonCrawl.Repo
  import Ecto.Query

  def up do
    alter table(:tile_templates) do
      add :slug, :string
    end

    flush()

    if System.get_env("MIGRATE_SLUG_DATA") == "true" do
      # TT's cannot have the same slug, fix manually after migration.
      execute """
              UPDATE tile_templates
              SET slug = translate(lower(name), ' ', '_')
              WHERE previous_version_id is null
              """
      _trickle_slugs()
    end
  end

  defp _trickle_slugs() do
    flush()

    if Repo.one(from tt in DungeonCrawl.TileTemplates.TileTemplate, select: count(), where: is_nil(tt.slug)) > 0 do
      next_version = Repo.one(from tt in DungeonCrawl.TileTemplates.TileTemplate, select: min(tt.version), where: is_nil(tt.slug))

      #query's ugly, but yolo
      execute """
              UPDATE tile_templates
              SET slug = tt0.slug
              FROM ( SELECT tt1.id, tt2.slug
                     FROM tile_templates AS tt1
                     JOIN tile_templates as tt2
                     ON tt2.id = tt1.previous_version_id
                     WHERE tt1.version = #{next_version} and tt1.slug is NULL ) AS tt0
              WHERE tt0.id = tile_templates.id
              """
      _trickle_slugs()
    end
  end

  def down do
    alter table(:tile_templates) do
      remove :slug
    end
  end
end

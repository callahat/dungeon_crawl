defmodule DungeonCrawl.Repo.Migrations.CreateTileTemplates do
  use Ecto.Migration

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Dungeon.MapTile

  def up do
    create table(:tile_templates) do
      add :name, :string
      add :character, :string
      add :description, :string
      add :color, :string
      add :background_color, :string
      add :responders, :string

      timestamps()
    end

    alter table(:dungeon_map_tiles) do
      add :tile_template_id, references(:tile_templates, on_delete: :nothing)
    end
    create index(:dungeon_map_tiles, [:tile_template_id])

    flush()

    if Mix.env != :test do
      template_map = DungeonCrawl.TileTemplates.TileSeeder.basic_tiles

      # Link all the map tiles that aren't already linked
      counts = Repo.all(MapTile)
               |> Enum.reduce(%{},fn(mt,acc) -> if template_map[mt.tile] do
                          Repo.update! MapTile.changeset(mt, %{tile_template_id: template_map[mt.tile].id})
                          Map.put(acc, mt.tile, if(acc[mt.tile], do: acc[mt.tile]+1, else: 1))
                        else
                          Map.put(acc, mt.tile, if(acc[mt.tile], do: acc[mt.tile]+1, else: 1))
                        end
               end)
      counts
      |> inspect
      |> IO.puts

      IO.puts "Characters that didn't exist in the template map (if any, add them and rereun seeds)"
      IO.puts inspect Map.keys(counts) -- Map.keys(template_map)
    end
  end

  def down do
    drop index(:dungeon_map_tiles, [:tile_template_id])
    alter table(:dungeon_map_tiles) do
      remove :tile_template_id
    end

    drop table(:tile_templates)
  end
end

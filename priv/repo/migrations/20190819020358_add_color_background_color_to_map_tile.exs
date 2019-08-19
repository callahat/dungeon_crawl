defmodule DungeonCrawl.Repo.Migrations.AddColorBackgroundColorToMapTile do
  use Ecto.Migration

  def up do
    alter table(:dungeon_map_tiles) do
      add :character, :string
      add :color, :string
      add :background_color, :string
    end

    alter table(:map_tile_instances) do
      add :character, :string
      add :color, :string
      add :background_color, :string
    end

    flush()

    # copy over color, background color, character to dungeon_map_tiles and map_tile_instances
    #execute "UPDATE dungeon_map_tiles dmt " <>
    #        "SET dmt.character = tt.character, dmt.color = tt.color, dmt.background_color = tt.background_color " <>
    #        "FROM tile_templates tt WHERE dmt.tile_template_id = tt.id "
    #execute "UPDATE map_tile_instances mti " <>
    #        "  SET mti.character = tt.character " <> #, mti.color = tt.color, mti.background_color = tt.background_color " <>
    #        "FROM tile_templates tt WHERE mti.tile_template_id = tt.id; "
    ["dungeon_map_tiles", "map_tile_instances"]
    |> Enum.each(fn(table) ->
         execute "UPDATE #{table} " <>
                 "  SET character = tt.character, color = tt.color, background_color = tt.background_color " <>
                 "FROM tile_templates tt " <>
                 "WHERE tile_template_id = tt.id"
       end)
  end

  def down do
    alter table(:dungeon_map_tiles) do
      remove :character
      remove :color
      remove :background_color
    end
    alter table(:map_tile_instances) do
      remove :character
      remove :color
      remove :background_color
    end
  end
end

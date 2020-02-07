defmodule DungeonCrawl.Repo.Migrations.ChangePlayerLocationToReferenceMapTile do
  use Ecto.Migration

  alias DungeonCrawl.Repo
  alias DungeonCrawl.Player.Location
  alias DungeonCrawl.Player
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Dungeon.MapTile

  def up do
    alter table(:player_locations) do
      add :map_tile_id, references(:dungeon_map_tiles, on_delete: :delete_all)
    end

    flush()

    #if Mix.env != :test do
    #  player_tile_template = DungeonCrawl.TileTemplates.TileSeeder.player_character_tile()

    #  # Add a map tile for each player
    #  Repo.all(Location)
    #  |> Enum.each(fn(l) ->
    #       player_tile = Dungeon.create_map_tile!(%{row: l.row, col: l.col, dungeon_id: l.dungeon_id, tile_template_id: player_tile_template.id, z_index: 1})
    #       Player.update_location!(l, %{map_tile_id: player_tile.id})
    #     end)
    #end
  end

  def down do
    #Repo.all(Location)
    #|> Repo.preload(:map_tile)
    #|> Enum.each(fn(l) ->
    #     Repo.delete!(l.map_tile)
    #   end)

    alter table(:player_locations) do
      remove :map_tile_id
    end
  end
end

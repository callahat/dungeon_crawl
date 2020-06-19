defmodule DungeonCrawl.TileTemplates.TileSeeder do
  # https://www.utf8-chartable.de/unicode-utf8-table.pl

  use DungeonCrawl.TileTemplates.TileSeeder.BasicTiles
  use DungeonCrawl.TileTemplates.TileSeeder.ColorDoors

  def seed_all() do
    # basic
    basic_tiles()
    bullet_tile()
    player_character_tile()

    # colored doors
    color_keys_and_doors()
    generic_colored_key()
    generic_colored_door()
  end
end

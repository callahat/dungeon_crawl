defmodule DungeonCrawl.TileTemplates.TileSeeder do
  # https://www.utf8-chartable.de/unicode-utf8-table.pl

  use DungeonCrawl.TileTemplates.TileSeeder.BasicTiles
  use DungeonCrawl.TileTemplates.TileSeeder.ColorDoors
  use DungeonCrawl.TileTemplates.TileSeeder.BlockWalls
  use DungeonCrawl.TileTemplates.TileSeeder.Creatures
  use DungeonCrawl.TileTemplates.TileSeeder.Ordinance
  use DungeonCrawl.TileTemplates.TileSeeder.Terrain

  def seed_all() do
    # basic
    basic_tiles()
    bullet_tile()
    player_character_tile()

    # colored doors
    color_keys_and_doors()
    generic_colored_key()
    generic_colored_door()

    # block walls
    solid_wall()
    normal_wall()
    breakable_wall()
    fake_wall()

    # creatures
    bandit()
    expanding_foam()
    pede_head()
    pede_body()

    # ordinance
    smoke()

    # terrain
    boulder()
    counter_clockwise_conveyor()
    clockwise_conveyor()
    grave()

    :ok
  end
end

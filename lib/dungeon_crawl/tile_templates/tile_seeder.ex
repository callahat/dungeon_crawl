defmodule DungeonCrawl.TileTemplates.TileSeeder do
  # https://www.utf8-chartable.de/unicode-utf8-table.pl

  use DungeonCrawl.TileTemplates.TileSeeder.BasicTiles
  use DungeonCrawl.TileTemplates.TileSeeder.ColorDoors
  use DungeonCrawl.TileTemplates.TileSeeder.BlockWalls
  use DungeonCrawl.TileTemplates.TileSeeder.Creatures
  use DungeonCrawl.TileTemplates.TileSeeder.Items
  use DungeonCrawl.TileTemplates.TileSeeder.Misc
  use DungeonCrawl.TileTemplates.TileSeeder.Ordinance
  use DungeonCrawl.TileTemplates.TileSeeder.Passageways
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
    invisible_wall()

    # creatures
    bandit()
    bear()
    expanding_foam()
    lion()
    pede_head()
    pede_body()
    tiger()
    zombie()

    # items
    ammo()
    cash()
    gem()
    heart()
    medkit()
    scroll()

    # misc
    beam_wall_emitter()
    beam_walls()
    clone_machine()
    pushers()
    spinning_gun()

    # ordinance
    bomb()
    explosion()
    smoke()
    star()
    star_emitter()

    # passageways
    passage()
    stairs_up()
    stairs_down()
    teleporters()

    # terrain
    boulder()
    counter_clockwise_conveyor()
    clockwise_conveyor()
    forest()
    junk_pile()
    lava()
    grave()
    ricochet()
    slider_horizontal()
    slider_vertical()

    :ok
  end
end

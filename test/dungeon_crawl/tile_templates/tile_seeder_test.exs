defmodule DungeonCrawl.TileTemplates.TileSeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates.TileSeeder
  alias DungeonCrawl.TileTemplates.TileTemplate

  test "basic_tiles returns the same map on subsequent calls" do
    assert  %{?. => _, ?# => _, ?\s => _, ?' => _, ?+ => _, ?@ => statue,
              "." => _, "#" => _, " " => _, "'" => _, "+" => _, "@" => statue} = basic_tiles = TileSeeder.basic_tiles()
    assert basic_tiles == TileSeeder.basic_tiles()
  end

  test "basic_tiles returns the map where the string and character code reference the same tile template" do
    basic_tiles = TileSeeder.basic_tiles()
    assert basic_tiles[?.]  == basic_tiles["."]
    assert basic_tiles[?#]  == basic_tiles["#"]
    assert basic_tiles[?\s] == basic_tiles[" "]
    assert basic_tiles[?']  == basic_tiles["'"]
    assert basic_tiles[?+]  == basic_tiles["+"]
    assert basic_tiles[?@]  == basic_tiles["@"]
  end

  test "bullet and player character tiles" do
    assert bullet_tile = TileSeeder.bullet_tile()
    assert player_character_tile = TileSeeder.player_character_tile()
    refute is_nil(bullet_tile.id)
    refute is_nil(player_character_tile.id)
  end

  test "color_keys_and_doors" do
    assert :ok = TileSeeder.color_keys_and_doors
    ["red", "green", "blue", "gray", "purple", "orange"]
    |> Enum.each(fn color ->
         color_key = "#{color} key"
         color_door = "#{color} door"
         assert Repo.one(from tt in TileTemplate, where: tt.name == ^color_key)
         assert Repo.one(from tt in TileTemplate, where: tt.name == ^color_door)
       end)

    assert TileSeeder.generic_colored_key
    assert TileSeeder.generic_colored_door
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Colored Key")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Colored Door")
  end

  test "block walls" do
    assert TileSeeder.solid_wall
    assert TileSeeder.normal_wall
    assert TileSeeder.breakable_wall
    assert TileSeeder.fake_wall
    assert TileSeeder.invisible_wall
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Solid Wall")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Normal Wall")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Breakable Wall")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Fake Wall")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Invisible Wall")
  end

  test "creatures" do
    assert TileSeeder.bandit
    assert TileSeeder.bear
    assert TileSeeder.expanding_foam
    assert TileSeeder.grid_bug
    assert TileSeeder.lion
    assert TileSeeder.pede_head
    assert TileSeeder.pede_body
    assert TileSeeder.rockworm
    assert TileSeeder.tiger
    assert TileSeeder.zombie
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Bandit")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Bear")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Expanding Foam")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Grid Bug")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Lion")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "PedeHead")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "PedeBody")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Rockworm")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Tiger")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Zombie")
  end

  test "items" do
    assert TileSeeder.ammo
    assert TileSeeder.cash
    assert TileSeeder.gem
    assert TileSeeder.heart
    assert TileSeeder.medkit
    assert TileSeeder.scroll
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Ammo")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Cash")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Gem")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Heart")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "MedKit")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Scroll")
  end

  test "misc" do
    assert TileSeeder.beam_wall_emitter
    assert TileSeeder.beam_walls
    assert TileSeeder.clone_machine
    assert TileSeeder.pushers
    assert TileSeeder.spinning_gun
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Beam Wall Horizontal")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Beam Wall Vertical")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Beam Wall Emitter")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Clone Machine")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Pusher North")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Pusher South")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Pusher East")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Pusher West")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Spinning Gun")
  end

  test "npcs" do
    assert TileSeeder.glad_trader
    assert TileSeeder.sad_trader
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Glad Trader")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Sad Trader")
  end

  test "ordinance" do
    assert TileSeeder.bomb
    assert TileSeeder.explosion
    assert TileSeeder.smoke
    assert TileSeeder.star
    assert TileSeeder.star_emitter
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Bomb")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Explosion")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Smoke")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Star")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Star Emitter")
  end

  test "passageways" do
    assert TileSeeder.passage
    assert TileSeeder.stairs_up
    assert TileSeeder.stairs_down
    assert TileSeeder.teleporters
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Passage")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Stairs Up")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Stairs Down")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Teleporter North")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Teleporter South")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Teleporter East")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Teleporter West")
  end

  test "terrain" do
    assert TileSeeder.boulder
    assert TileSeeder.counter_clockwise_conveyor
    assert TileSeeder.clockwise_conveyor
    assert TileSeeder.forest
    assert TileSeeder.junk_pile
    assert TileSeeder.lava
    assert TileSeeder.grave
    assert TileSeeder.ricochet
    assert TileSeeder.slider_horizontal
    assert TileSeeder.slider_vertical
    assert TileSeeder.water
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Boulder")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Counter Clockwise Conveyor")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Clockwise Conveyor")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Forest")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Junk Pile")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Lava")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Grave")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Ricochet")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Slider Horizontal")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Slider Vertical")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Water")
  end

  test "seed_all/0" do
    initial_count = Repo.one(from t in TileTemplate, select: count(t.id))
    TileSeeder.seed_all()
    seeded_count = Repo.one(from t in TileTemplate, select: count(t.id))
    assert seeded_count - initial_count == 78

    # does not add the seeds again
    TileSeeder.seed_all()
    seeded_count2 = Repo.one(from t in TileTemplate, select: count(t.id))
    assert seeded_count2 - initial_count == 78
  end
end

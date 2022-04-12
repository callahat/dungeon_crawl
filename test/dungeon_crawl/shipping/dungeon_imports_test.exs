defmodule DungeonCrawl.Shipping.DungeonImportsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports
  alias DungeonCrawl.Shipping.DungeonImports

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileSeeder

  setup do
    # level 1 is empty

    # level 2
    # 0123_
    #0 . ._
    #1 .+._
    #2 ###_

    # level 3
    # 0123_
    #0 .. _
    #1 .x _
    #2    _

    # only some of the assets exist
    gun = Equipment.Seeder.gun()
    stone = Equipment.Seeder.stone()
    items = %{gun: gun, stone: stone}

    alarm = Sound.Seeder.alarm()
    pickup_blip = Sound.Seeder.pickup_blip()
    shoot = Sound.Seeder.shoot()
    sounds = %{alarm: alarm, pickup_blip: pickup_blip, shoot: shoot}

    rock = TileSeeder.rock_tile()
    stone_tile = TileSeeder.stone()
    existing_tiles = %{rock: rock, stone: stone_tile}

    user = insert_user()

    # Reusing the setup from DungeonExport, and then exporting that for the test dump is significantly less
    # lines. Additionally, the two modules are meant to be somewhat tightly coupled; the import
    # takes the output of the export. So this also has the benifit of likely noticably breaking
    # should the contract change with one and not the other.
    export_hash = DungeonCrawlWeb.ExportFixture.export

    %{export_hash: export_hash, user: user, sounds: sounds, items: items, existing_tiles: existing_tiles}
  end

  test "run/2", config do
    user_id = config.user.id

    tile_template_count = Enum.count(TileTemplates.list_tile_templates())
    sound_count = Enum.count(Sound.list_effects())
    item_count = Enum.count(Equipment.list_items())

    # what was created in setup
    assert tile_template_count == 2
    assert sound_count == 3
    assert item_count == 2

    # While the export hash returned is not the main use of the importer, this struct
    # is updated with the found/created assets
    assert %DungeonExports{
             dungeon: dungeon,
             tile_templates: tile_templates,
             tiles: tiles,
             levels: levels,
           } = DungeonImports.run(config.export_hash, user_id)

    assert 6 == Enum.count(TileTemplates.list_tile_templates()) - tile_template_count
    assert 3 == Enum.count(Sound.list_effects()) - sound_count
    assert 2 == Enum.count(Equipment.list_items()) - item_count

    # assets created or found
    # tile templates
    assert config.existing_tiles.rock == TileTemplates.get_tile_template_by_slug("rock")
    assert config.existing_tiles.stone == TileTemplates.get_tile_template_by_slug("stone")
    assert floor = TileTemplates.find_tile_template(%{name: "Floor", user_id: user_id, public: false})
    assert closed_door = TileTemplates.find_tile_template(%{name: "Closed Door", user_id: user_id, public: false})
    assert open_door = TileTemplates.find_tile_template(%{name: "Open Door", user_id: user_id, public: false})
    assert wall = TileTemplates.find_tile_template(%{name: "Wall", user_id: user_id, public: false})
    assert fireball = TileTemplates.find_tile_template(%{name: "Fireball", user_id: user_id, public: false})
    assert explosion = TileTemplates.find_tile_template(%{name: "Explosion", user_id: user_id, public: false})

    assert comp_tt_fields(floor)
           == comp_tt_fields(config.export_hash.tile_templates["tmp_tt_id_2"])
    assert comp_tt_fields(closed_door)
           == comp_tt_fields(config.export_hash.tile_templates["tmp_tt_id_4"])
    assert comp_tt_fields(open_door)
           == comp_tt_fields(config.export_hash.tile_templates["tmp_tt_id_5"])
    assert comp_tt_fields(wall)
           == comp_tt_fields(config.export_hash.tile_templates["tmp_tt_id_6"])
    assert comp_tt_fields(fireball)
           == comp_tt_fields(config.export_hash.tile_templates["tmp_tt_id_0"])
    assert comp_tt_fields(explosion)
           == comp_tt_fields(config.export_hash.tile_templates["tmp_tt_id_1"])

    assert floor.id == tile_templates["tmp_tt_id_2"].id
    assert closed_door.id == tile_templates["tmp_tt_id_4"].id
    assert open_door.id == tile_templates["tmp_tt_id_5"].id
    assert wall.id == tile_templates["tmp_tt_id_6"].id
    assert fireball.id == tile_templates["tmp_tt_id_0"].id
    assert explosion.id == tile_templates["tmp_tt_id_1"].id

    assert floor.active
    assert closed_door.active
    assert open_door.active
    assert wall.active
    assert fireball.active
    assert explosion.active

    assert Map.take(floor, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "floor_#{ floor.id }", public: false}
    assert Map.take(closed_door, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "closed_door_#{ closed_door.id }", public: false}
    assert Map.take(open_door, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "open_door_#{ open_door.id }", public: false}
    assert Map.take(wall, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "wall_#{ wall.id }", public: false}
    assert Map.take(fireball, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "fireball_#{ fireball.id }", public: false}
    assert Map.take(explosion, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "explosion_#{ explosion.id }", public: false}

    # sounds effects
    assert config.sounds.alarm == Sound.get_effect_by_slug("alarm")
    assert config.sounds.pickup_blip == Sound.get_effect_by_slug("pickup_blip")
    assert config.sounds.shoot == Sound.get_effect_by_slug("shoot")
    assert click = Sound.find_effect(%{name: "Click", user_id: user_id, public: false})
    assert bomb = Sound.find_effect(%{name: "Bomb", user_id: user_id, public: false})
    assert door = Sound.find_effect(%{name: "Door", user_id: user_id, public: false})

    assert comp_sound_fields(click)
           == comp_sound_fields(config.export_hash.sounds["tmp_sound_id_1"])
    assert comp_sound_fields(bomb)
           == comp_sound_fields(config.export_hash.sounds["tmp_sound_id_2"])
    assert comp_sound_fields(door)
           == comp_sound_fields(config.export_hash.sounds["tmp_sound_id_3"])

    assert Map.take(click, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "click_#{ click.id }", public: false}
    assert Map.take(bomb, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "bomb_#{ bomb.id }", public: false}
    assert Map.take(door, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "door_#{ door.id }", public: false}

    # items
    assert config.items.gun == Equipment.get_item("gun")
    assert config.items.stone == Equipment.get_item("stone")
    # the seeded gun referenced a nonexistant slug, so the import created a new gun
    # if this happened, something was probably corrupted in the destination system.
    assert gun = Equipment.find_item(%{name: "Gun", user_id: user_id, public: false})
    assert wand = Equipment.find_item(%{name: "Fireball Wand", user_id: user_id, public: false})

    assert comp_item_fields(gun)
           == comp_item_fields(config.export_hash.items["tmp_item_id_0"])
    assert comp_item_fields(wand)
           == comp_item_fields(config.export_hash.items["tmp_item_id_1"])

    assert Map.take(gun, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "gun_#{ gun.id }", public: false}
    assert Map.take(wand, [:user_id, :slug, :public])
           == %{user_id: user_id, slug: "fireball_wand_#{ wand.id }", public: false}

    # tiles
    assert {_floor_hash, floor_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor" end)
    assert {_wall_hash, wall_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Wall" end)
    assert {_rock_hash, rock_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Rock" end)
    assert {_c_door_hash, c_door_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Closed Door" end)
    assert {_floor2_hash, floor2_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor 2" end)
    assert {_custom_hash, custom_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "" end)

    assert Map.take(floor_tile, [:tile_template_id, :script])
           == %{tile_template_id: floor.id, script: ""}
    assert Map.take(wall_tile, [:tile_template_id, :script])
           == %{tile_template_id: wall.id, script: ""}
    assert Map.take(rock_tile, [:tile_template_id, :script])
           == %{tile_template_id: config.existing_tiles.rock.id, script: ""}
    assert Map.take(c_door_tile, [:tile_template_id, :script])
           == %{tile_template_id: closed_door.id,
                script: "#END\n:OPEN\n#SOUND #{door.slug}\n#BECOME slug: #{open_door.slug}"}
    assert Map.take(floor2_tile, [:tile_template_id, :script, :state])
           == %{tile_template_id: floor.id, state: "light_source: true", script: ""}
    assert Map.take(custom_tile, [:tile_template_id, :script])
           == %{tile_template_id: nil,
             script: "#end\n:touch\n#sound #{config.sounds.alarm.slug}\n#equip #{config.items.stone.slug}, ?sender\n#become slug: #{wall.slug}\n#unequip #{gun.slug}, ?sender\n/i\n#sound #{config.sounds.alarm.slug}"}

    floor_tile = Map.delete(floor_tile, :tmp_script)
    wall_tile = Map.delete(wall_tile, :tmp_script)
    rock_tile = Map.delete(rock_tile, :tmp_script)
    c_door_tile = Map.delete(c_door_tile, :tmp_script)
    floor2_tile = Map.delete(floor2_tile, :tmp_script)
    custom_tile = Map.delete(custom_tile, :tmp_script)

    # verify scripts have the right slugs
    # items
    assert gun.script == """
      #take ammo, 1, ?self, error
      #shoot @facing
      #sound #{ config.sounds.shoot.slug }
      #end
      :error
      Out of ammo!
      #sound #{ click.slug }
      """
    assert wand.script == """
      #put direction: here, slug: #{ fireball.slug }, facing: @facing, owner: ?self
      #take gems, 1, ?self, it_might_break
      #end
      :it_might_break
      #if ?random@10 != 10, 1
      #end
      The wand broke!
      #if ?random@4 != 4, 2
      #put slug: #{ explosion.slug }, shape: circle, range: 3, damage: 10, owner: ?self
      #sound #{ bomb.slug }
      #die
      """

    # tile templates
    assert floor.script == ""
    assert closed_door.script == "#END\n:OPEN\n#SOUND #{ door.slug }\n#BECOME slug: #{ open_door.slug }"
    assert open_door.script == "#END\n:CLOSE\n#SOUND #{ door.slug }\n#BECOME slug: #{ closed_door.slug }"
    assert wall.script == ""
    assert fireball.script == """
      :MAIN
      #WALK @facing
      :THUD
      #SOUND #{ bomb.slug }
      #PUT slug: #{ explosion.slug }, shape: circle, range: 2, damage: 10, owner: @owner
      #DIE
      """
    assert explosion.script == """
      #SEND bombed, here
      :TOP
      #RANDOM c, red, orange, yellow
      #BECOME color: @c
      ?i
      @count -= 1
      #IF @count > 0, top
      #DIE
      """

    # verify dungeon record and its details
    line_identifier = dungeon.line_identifier
    dungeon_state = "test: true, starting_equipment: #{ gun.slug } #{ wand.slug }"
    assert %{
      autogenerated: false,
      default_map_height: 20,
      default_map_width: 20,
      description: "testing",
      line_identifier: ^line_identifier,
      name: "Exporter",
      state: ^dungeon_state,
      title_number: 2,
      user_id: ^user_id,
      version: 1,
      active: false} = dungeon
    # no specified line, so the imported dungeon becomes its own line
    assert dungeon.id == dungeon.line_identifier
    assert dungeon == Dungeons.get_dungeon!(dungeon.id)

    # verify level records and their details
    assert 3 == map_size(levels)
    assert %{1 => level_1,
             2 => level_2,
             3 => level_3} = levels

    assert %{
      dungeon_id: dungeon.id,
      entrance: nil,
      height: 20,
      width: 20,
      name: "Stubbed",
      number: 1,
      number_east: nil,
      number_west: nil,
      number_north: nil,
      number_south: nil,
      state: nil,
    } == comp_level_fields(level_1)
    assert %{
      dungeon_id: dungeon.id,
      entrance: true,
      height: 20,
      width: 20,
      name: "one",
      number: 2,
      number_east: nil,
      number_west: nil,
      number_north: 3,
      number_south: nil,
      state: nil,
    } == comp_level_fields(level_2)
    assert %{
      dungeon_id: dungeon.id,
      entrance: nil,
      height: 20,
      width: 20,
      name: "Stubbed",
      number: 3,
      number_east: nil,
      number_west: nil,
      number_north: nil,
      number_south: nil,
      state: "visibility: fog",
    } == comp_level_fields(level_3)

    level_1_tiles = Repo.preload(level_1, :tiles).tiles
                    |> Enum.map(fn(t) -> Dungeons.copy_tile_fields(t) end)
                    |> Enum.sort
    assert [] == level_1_tiles
    assert [] == Repo.preload(level_1, :spawn_locations).spawn_locations
                 |> Enum.map(fn(sl) -> {sl.row, sl.col} end)

    level_2_tiles = Repo.preload(level_2, :tiles).tiles
                    |> Enum.map(fn(t) -> Dungeons.copy_tile_fields(t) end)
                    |> Enum.sort
    level_2_expected_tiles = [
      Map.merge(%{row: 0, col: 1, z_index: 0}, floor_tile),
      Map.merge(%{row: 0, col: 2, z_index: 0}, rock_tile),
      Map.merge(%{row: 0, col: 3, z_index: 0}, floor_tile),
      Map.merge(%{row: 1, col: 1, z_index: 0}, floor_tile),
      Map.merge(%{row: 1, col: 2, z_index: 0}, c_door_tile),
      Map.merge(%{row: 1, col: 3, z_index: 0}, floor_tile),
      Map.merge(%{row: 2, col: 1, z_index: 0}, wall_tile),
      Map.merge(%{row: 2, col: 2, z_index: 0}, wall_tile),
      Map.merge(%{row: 2, col: 3, z_index: 0}, wall_tile),
    ] |> Enum.sort
    assert level_2_expected_tiles == level_2_tiles
    assert Enum.sort([{0, 1}, {0, 3}])
           == Repo.preload(level_2, :spawn_locations).spawn_locations
              |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
              |> Enum.sort()

    level_3_tiles = Repo.preload(level_3, :tiles).tiles
                    |> Enum.map(fn(t) -> Dungeons.copy_tile_fields(t) end)
                    |> Enum.sort
    level_3_expected_tiles = [
      Map.merge(%{row: 0, col: 1, z_index: 0}, floor_tile),
      Map.merge(%{row: 0, col: 2, z_index: 0}, floor_tile),
      Map.merge(%{row: 1, col: 1, z_index: 0}, floor2_tile),
      Map.merge(%{row: 1, col: 2, z_index: 1}, Map.put(custom_tile, :name, nil)),
    ] |> Enum.sort
    assert level_3_expected_tiles == level_3_tiles
    assert [{1, 1}]
           == Repo.preload(level_3, :spawn_locations).spawn_locations
              |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
  end

  test "run/3 latest dungeon of line is active", config do
    prev_dungeon = insert_dungeon(%{line_identifier: 101010, active: true, user_id: config.user.id})
    assert %DungeonExports{
             dungeon: dungeon,
           } = DungeonImports.run(config.export_hash, config.user.id, prev_dungeon.line_identifier)
    assert dungeon.line_identifier == prev_dungeon.line_identifier
    assert %{deleted_at: nil} = Dungeons.get_dungeon(prev_dungeon.id)
    assert dungeon.version == prev_dungeon.version + 1
    assert dungeon.previous_version_id == prev_dungeon.id
  end

  test "run/3 latest dungeon of line is inactive", config do
    inactive_dungeon = insert_dungeon(%{line_identifier: 90210, active: false, user_id: config.user.id})
    assert %DungeonExports{
             dungeon: dungeon,
           } = DungeonImports.run(config.export_hash, config.user.id, inactive_dungeon.line_identifier)
    assert dungeon.line_identifier == inactive_dungeon.line_identifier
    refute Dungeons.get_dungeon(inactive_dungeon.id)
    assert dungeon.version == inactive_dungeon.version
    assert dungeon.previous_version_id == inactive_dungeon.previous_version_id
  end

  test "run/3 the line is owned by someone else", config do
    other_user = insert_user()
    inactive_dungeon = insert_dungeon(%{line_identifier: 90210, active: false, user_id: other_user.id})
    assert %DungeonExports{
             dungeon: dungeon,
           } = DungeonImports.run(config.export_hash, config.user.id, inactive_dungeon.line_identifier)
    refute dungeon.line_identifier == inactive_dungeon.line_identifier
    assert Dungeons.get_dungeon(inactive_dungeon.id)
    assert dungeon.version == 1
    refute dungeon.previous_version_id
  end

  def comp_item_fields(item) do
    Equipment.copy_fields(item)
    |> Map.drop([:temp_item_id, :script, :user_id, :public, :slug])
  end

  def comp_sound_fields(sound) do
    Sound.copy_fields(sound)
    |> Map.drop([:temp_sound_id, :user_id, :public, :slug])
  end

  def comp_tt_fields(tt) do
    TileTemplates.copy_fields(tt)
    |> Map.drop([:temp_tt_id, :script, :user_id, :public, :slug])
  end

  def comp_level_fields(level) do
    Map.take(level, [
      :dungeon_id,
      :entrance,
      :height,
      :width,
      :name,
      :number,
      :number_east,
      :number_west,
      :number_north,
      :number_south,
      :state])
  end
end

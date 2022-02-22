defmodule DungeonCrawl.Shipping.DungeonExportsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
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

    gun = Equipment.Seeder.gun()
    stone = Equipment.Seeder.stone()
    fireball_wand = Equipment.Seeder.fireball_wand()
    items = %{gun: gun, stone: stone, fireball_wand: fireball_wand}

    alarm = Sound.Seeder.alarm()
    door = Sound.Seeder.door()
    sounds = %{alarm: alarm, door: door}

    %{?.  => floor, ?#  => wall, ?\s => rock, ?+  => c_door, ?' => o_door} = TileSeeder.basic_tiles()
    basic_tiles = %{floor: floor, wall: wall, rock: rock, closed_door: c_door, open_door: o_door}

    user = insert_user()

    dungeon_attrs = %{
      name: "Exporter",
      description: "testing",
      user_id: user.id,
      state: "test: true, starting_equipment: gun fireball_wand",
      default_map_width: 20,
      default_map_height: 20,
      line_identifier: 1,
      title_number: 2
    }

    level_1_tiles = [
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 1, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(rock),  %{row: 0, col: 2, z_index: 0, tile_template_id: rock.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 3, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 1, col: 1, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(c_door),  %{row: 1, col: 2, z_index: 0, tile_template_id: c_door.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 1, col: 3, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(wall),  %{row: 2, col: 1, z_index: 0, tile_template_id: wall.id}),
      Map.merge(Dungeons.copy_tile_fields(wall),  %{row: 2, col: 2, z_index: 0, tile_template_id: wall.id}),
      Map.merge(Dungeons.copy_tile_fields(wall),  %{row: 2, col: 3, z_index: 0, tile_template_id: wall.id})
    ]
    level_2_tiles = [
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 1, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 2, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 1, col: 1, z_index: 0, tile_template_id: floor.id, state: "light_source: true", name: "Floor 2"}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 1, z_index: 0, tile_template_id: floor.id}),
      %{name: "", row: 1, col: 2, z_index: 1, character: "x", state: "blocking: true", script: "#end\n:touch\n#sound alarm\n#equip stone, ?sender\n#become wall"}
    ]

    dungeon  = insert_stubbed_dungeon(dungeon_attrs)
    level_1 = insert_stubbed_level(
      %{
        dungeon_id: dungeon.id,
        name: "one",
        entrance: true,
        number: 2,
        number_north: 2},
      level_1_tiles)
    level_2 = insert_stubbed_level(
      %{
        dungeon_id: dungeon.id,
        number: 3,
        state: "visibility: fog"},
      level_2_tiles)

    %{dungeon: dungeon, level_1: level_1, level_2: level_2, user: user, sounds: sounds, items: items, basic_tiles: basic_tiles}
  end

  test "run/1", export do
    export_hash = DungeonExports.run(export.dungeon.id)
    assert %{
             dungeon: dungeon,
             levels: levels,
             tiles: tiles,
             items: items,
             tile_templates: tile_templates,
             sounds: sounds
           } = export_hash
    IO.inspect export_hash

    assert {tmp_gun_item_id, gun} = Enum.find(items, fn {_, item} -> item.name == "Gun" end)
    assert {tmp_wand_item_id, wand} = Enum.find(items, fn {_, item} -> item.name == "Fireball Wand" end)
    assert {tmp_stone_item_id, stone} = Enum.find(items, fn {_, item} -> item.name == "Stone" end)
    # todo: verify temp item attributes

    assert {tmp_alarm_sound_id, alarm} = Enum.find(sounds, fn {_, sound} -> sound.name == "Alarm" end)
    # todo: verify temp sound attributes

    assert {tmp_floor_id, floor} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor" end)
    assert {tmp_wall_id, wall} = Enum.find(tiles, fn {_, tile} -> tile.name == "Wall" end)
    assert {tmp_rock_id, rock} = Enum.find(tiles, fn {_, tile} -> tile.name == "Rock" end)
    assert {tmp_floor2_id, floor2} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor" end)
    assert {tmp_custom_id, custom_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "" end)
    # todo: verify tiles attributes
IO.inspect tile_templates
    assert {tmp_floor_tt_id, floor_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Floor" end)
    assert {tmp_wall_tt_id, wall_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Wall" end)
    assert {tmp_rock_tt_id, rock_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Rock" end)
    assert {tmp_c_door_tt_id, c_door_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Closed Door" end)
    assert {tmp_o_door_tt_id, o_door_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Open Door" end)
    # todo: verify temp tile template attributes

    assert %{1 => level_1, 2 => level_2, 3 => level_3} = levels
    # todo: verify level contets

    assert dungeon == Dungeons.copy_dungeon_fields(export.dungeon)
  end
end

defmodule DungeonCrawl.Shipping.DungeonExportsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
  alias DungeonCrawl.TileTemplates.{TileSeeder, TileTemplate}

  @custom_tt %TileTemplate{
               name: "",
               character: "x",
               state: "blocking: true",
               script: "#end\n:touch\n#sound alarm\n#equip stone, ?sender\n#become slug: wall\n#unequip gun, ?sender\n/i\n#sound alarm"
             }

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

    level_2_tiles = [
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
    level_3_tiles = [
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 1, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 2, z_index: 0, tile_template_id: floor.id}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 1, col: 1, z_index: 0, tile_template_id: floor.id, state: "light_source: true", name: "Floor 2"}),
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 0, col: 1, z_index: 0, tile_template_id: floor.id}),
      Map.merge(@custom_tt, %{row: 1, col: 2, z_index: 1})
    ]

    dungeon  = insert_stubbed_dungeon(dungeon_attrs)
    level_2 = insert_stubbed_level(
      %{
        dungeon_id: dungeon.id,
        name: "one",
        entrance: true,
        number: 2,
        number_north: 3},
      level_2_tiles)
    level_3 = insert_stubbed_level(
      %{
        dungeon_id: dungeon.id,
        number: 3,
        state: "visibility: fog"},
      level_3_tiles)

    Dungeons.add_spawn_locations(level_2.id, [{0,1}, {0,3}])
    Dungeons.add_spawn_locations(level_3.id, [{1,1}])

    %{dungeon: dungeon, level_2: level_2, level_3: level_3, user: user, sounds: sounds, items: items, basic_tiles: basic_tiles}
  end

  test "run/1", export do
    export_hash = DungeonExports.run(export.dungeon.id)
    assert %DungeonExports{
             dungeon: dungeon,
             levels: levels,
             tiles: tiles,
             items: items,
             tile_templates: tile_templates,
             sounds: sounds,
             spawn_locations: spawn_locations,
           } = export_hash

    # Items
    assert {"gun", gun} = Enum.find(items, fn {_, item} -> item.name == "Gun" end)
    assert {"fireball_wand", wand} = Enum.find(items, fn {_, item} -> item.name == "Fireball Wand" end)
    assert {"stone", stone} = Enum.find(items, fn {_, item} -> item.name == "Stone" end)

    assert export.items.gun == Map.delete(gun, :temp_item_id)
    assert export.items.fireball_wand == Map.delete(wand, :temp_item_id)
    assert export.items.stone == Map.delete(stone, :temp_item_id)
    assert %{temp_item_id: tmp_gun_id} = gun
    assert %{temp_item_id: _tmp_wand_id} = wand
    assert %{temp_item_id: tmp_stone_id} = stone

    # Sounds
    assert {"alarm", alarm} = Enum.find(sounds, fn {_, sound} -> sound.name == "Alarm" end)
    assert {"door", door} = Enum.find(sounds, fn {_, sound} -> sound.name == "Door" end)

    assert export.sounds.alarm == Map.delete(alarm, :temp_sound_id)
    assert export.sounds.door == Map.delete(door, :temp_sound_id)
    assert %{temp_sound_id: tmp_alarm_id} = alarm
    assert %{temp_sound_id: tmp_door_id} = door

    # Tile templates
    assert {floor_tt_id, floor_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Floor" end)
    assert {wall_tt_id, wall_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Wall" end)
    assert {rock_tt_id, rock_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Rock" end)
    assert {c_door_tt_id, c_door_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Closed Door" end)
    assert {o_door_tt_id, o_door_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Open Door" end)

    assert floor_tt_id == export.basic_tiles.floor.id
    assert wall_tt_id == export.basic_tiles.wall.id
    assert rock_tt_id == export.basic_tiles.rock.id
    assert c_door_tt_id == export.basic_tiles.closed_door.id
    assert o_door_tt_id == export.basic_tiles.open_door.id

    assert export.basic_tiles.floor == Map.delete(floor_tt, :temp_tt_id)
    assert export.basic_tiles.wall == Map.delete(wall_tt, :temp_tt_id)
    assert export.basic_tiles.rock == Map.delete(rock_tt, :temp_tt_id)
    assert export.basic_tiles.closed_door == Map.delete(c_door_tt, :temp_tt_id)
    assert export.basic_tiles.open_door == Map.delete(o_door_tt, :temp_tt_id)
    assert %{temp_tt_id: _tmp_floor_tt_id} = floor_tt
    assert %{temp_tt_id: tmp_wall_tt_id} = wall_tt
    assert %{temp_tt_id: _tmp_rock_tt_id} = rock_tt
    assert %{temp_tt_id: _tmp_c_door_tt_id} = c_door_tt
    assert %{temp_tt_id: tmp_o_door_tt_id} = o_door_tt

    # Tiles
    assert {floor_hash, floor} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor" end)
    assert {wall_hash, wall} = Enum.find(tiles, fn {_, tile} -> tile.name == "Wall" end)
    assert {rock_hash, rock} = Enum.find(tiles, fn {_, tile} -> tile.name == "Rock" end)
    assert {c_door_hash, c_door} = Enum.find(tiles, fn {_, tile} -> tile.name == "Closed Door" end)
    assert {floor2_hash, floor2} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor 2" end)
    assert {custom_hash, custom_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "" end)

    assert Dungeons.copy_tile_fields(export.basic_tiles.floor) == Map.delete(floor, :tile_template_id)
    assert Dungeons.copy_tile_fields(export.basic_tiles.wall) == Map.delete(wall, :tile_template_id)
    assert Dungeons.copy_tile_fields(export.basic_tiles.rock) == Map.delete(rock, :tile_template_id)
    assert Dungeons.copy_tile_fields(export.basic_tiles.closed_door)
           |> Map.put(:script, "#END\n:OPEN\n#BECOME slug: #{tmp_o_door_tt_id}\n#SOUND #{tmp_door_id}" )
           == Map.delete(c_door, :tile_template_id)
    assert Map.merge(Dungeons.copy_tile_fields(export.basic_tiles.floor), %{state: "light_source: true", name: "Floor 2"}) == Map.delete(floor2, :tile_template_id)
    assert Dungeons.copy_tile_fields(@custom_tt)
           |> Map.put(:script, "#end\n:touch\n#sound #{tmp_alarm_id}\n#equip #{tmp_stone_id}, ?sender\n#become slug: #{tmp_wall_tt_id}\n#unequip #{tmp_gun_id}, ?sender\n/i\n#sound #{tmp_alarm_id}")
           == Map.delete(custom_tile, :tile_template_id)

    # and the above `assert 1==...` should be updated accordingly
    assert floor.tile_template_id == floor_tt.temp_tt_id
    assert wall.tile_template_id == wall_tt.temp_tt_id
    assert rock.tile_template_id == rock_tt.temp_tt_id
    assert c_door.tile_template_id == c_door_tt.temp_tt_id
    assert floor2.tile_template_id == floor_tt.temp_tt_id
    assert is_nil(custom_tile.tile_template_id)

    # Levels
    assert %{1 => level_1, 2 => level_2, 3 => level_3} = levels

    assert %{entrance: nil,
             height: 20,
             width: 20,
             name: "Stubbed",
             number: 1,
             tile_data: level_1_tile_data} = level_1
    assert %{} == level_1_tile_data

    assert %{entrance: true,
             height: 20,
             width: 20,
             name: "one",
             number: 2,
             number_north: 3,
             tile_data: level_2_tile_data} = level_2
    assert %{
             {0, 1, 0} => floor_hash,
             {0, 2, 0} => rock_hash,
             {0, 3, 0} => floor_hash,
             {1, 1, 0} => floor_hash,
             {1, 2, 0} => c_door_hash,
             {1, 3, 0} => floor_hash,
             {2, 1, 0} => wall_hash,
             {2, 2, 0} => wall_hash,
             {2, 3, 0} => wall_hash
           } == level_2_tile_data

    assert %{entrance: nil,
             height: 20,
             width: 20,
             name: "Stubbed",
             number: 3,
             state: "visibility: fog",
             tile_data: level_3_tile_data} = level_3
    assert %{
             {0, 1, 0} => floor_hash,
             {0, 2, 0} => floor_hash,
             {1, 1, 0} => floor2_hash,
             {1, 2, 1} => custom_hash
           } == level_3_tile_data

    # spawn locations
    assert [{2, 0, 1}, {2, 0, 3}, {3, 1, 1}] == spawn_locations

    # Dungeon
    assert Map.delete(dungeon, :state) == Map.delete(Dungeons.copy_dungeon_fields(export.dungeon), :state)
    assert String.contains?(dungeon.state, "starting_equipment: #{gun.temp_item_id} #{wand.temp_item_id}")
  end

  test "run/1 dungeon without starting_equipment", export do
    {:ok, updated_dungeon} = Dungeons.update_dungeon(export.dungeon, %{state: "foo: bar"})
    Dungeons.delete_level!(export.level_2)
    Dungeons.delete_level!(export.level_3)

    export_hash = DungeonExports.run(updated_dungeon.id)

    assert %DungeonExports{
             dungeon: dungeon,
             items: items,
             spawn_locations: spawn_locations,
           } = export_hash

    assert [{"gun", gun}] = Map.to_list(items)

    assert export.items.gun == Map.delete(gun, :temp_item_id)
    assert %{temp_item_id: _tmp_gun_id} = gun

    assert [] == spawn_locations

    assert dungeon == Dungeons.copy_dungeon_fields(updated_dungeon)
  end
end

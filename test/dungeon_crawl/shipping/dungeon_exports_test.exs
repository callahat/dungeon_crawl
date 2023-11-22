defmodule DungeonCrawl.Shipping.DungeonExportsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.{TileSeeder, TileTemplate}

  @custom_tt %TileTemplate{
               name: "",
               character: "x",
               state: %{"blocking" => true},
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
    bomb = Sound.Seeder.bomb()
    click = Sound.Seeder.click()
    door = Sound.Seeder.door()
    shoot = Sound.Seeder.shoot()
    pickup_blip = Sound.Seeder.pickup_blip()
    sounds = %{alarm: alarm, bomb: bomb, click: click, door: door, shoot: shoot, pickup_blip: pickup_blip}

    %{?.  => floor, ?#  => wall, ?\s => rock, ?+  => c_door, ?' => o_door} = TileSeeder.basic_tiles()
    fireball = TileSeeder.fireball()
    explosion = TileSeeder.explosion()
    stone_tt = TileSeeder.stone()
    basic_tiles = %{
      floor: floor,
      wall: wall,
      rock: rock,
      closed_door: c_door,
      open_door: o_door,
      fireball: fireball,
      explosion: explosion,
      stone: stone_tt
    }

    user = insert_user()

    dungeon_attrs = %{
      name: "Exporter",
      description: "testing",
      user_id: user.id,
      state: %{"test" => true, "starting_equipment" => ["gun", "fireball_wand"]},
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
      Map.merge(Dungeons.copy_tile_fields(floor), %{row: 1, col: 1, z_index: 0, tile_template_id: floor.id, state: %{"light_source" => true}, name: "Floor 2"}),
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
        state: %{"visibility" => "fog"}},
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
    assert {tmp_gun_id, gun} = Enum.find(items, fn {_, item} -> item.name == "Gun" end)
    assert {tmp_wand_id, wand} = Enum.find(items, fn {_, item} -> item.name == "Fireball Wand" end)
    assert {tmp_stone_id, stone} = Enum.find(items, fn {_, item} -> item.name == "Stone" end)

    assert comp_item_fields(export.items.gun) == comp_item_fields(gun)
    assert comp_item_fields(export.items.fireball_wand) == comp_item_fields(wand)
    assert comp_item_fields(export.items.stone) == comp_item_fields(stone)
    assert %{temp_item_id: ^tmp_gun_id} = gun
    assert %{temp_item_id: ^tmp_wand_id} = wand
    assert %{temp_item_id: ^tmp_stone_id} = stone

    # Sounds
    assert {tmp_alarm_id, alarm} = Enum.find(sounds, fn {_, sound} -> sound.name == "Alarm" end)
    assert {tmp_bomb_id, bomb} = Enum.find(sounds, fn {_, sound} -> sound.name == "Bomb" end)
    assert {tmp_click_id, click} = Enum.find(sounds, fn {_, sound} -> sound.name == "Click" end)
    assert {tmp_door_id, door} = Enum.find(sounds, fn {_, sound} -> sound.name == "Door" end)
    assert {tmp_shoot_id, shoot} = Enum.find(sounds, fn {_, sound} -> sound.name == "Shoot" end)
    assert {tmp_pickup_blip_id, pickup_blip} = Enum.find(sounds, fn {_, sound} -> sound.name == "Pickup Blip" end)

    assert Sound.copy_fields(export.sounds.alarm) == Map.delete(alarm, :temp_sound_id)
    assert Sound.copy_fields(export.sounds.bomb) == Map.delete(bomb, :temp_sound_id)
    assert Sound.copy_fields(export.sounds.click) == Map.delete(click, :temp_sound_id)
    assert Sound.copy_fields(export.sounds.door) == Map.delete(door, :temp_sound_id)
    assert Sound.copy_fields(export.sounds.shoot) == Map.delete(shoot, :temp_sound_id)
    assert Sound.copy_fields(export.sounds.pickup_blip) == Map.delete(pickup_blip, :temp_sound_id)
    assert %{temp_sound_id: ^tmp_alarm_id} = alarm
    assert %{temp_sound_id: ^tmp_bomb_id} = bomb
    assert %{temp_sound_id: ^tmp_click_id} = click
    assert %{temp_sound_id: ^tmp_door_id} = door
    assert %{temp_sound_id: ^tmp_shoot_id} = shoot
    assert %{temp_sound_id: ^tmp_pickup_blip_id} = pickup_blip

    # Tile templates
    assert {tmp_floor_tt_id, floor_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Floor" end)
    assert {tmp_wall_tt_id, wall_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Wall" end)
    assert {tmp_rock_tt_id, rock_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Rock" end)
    assert {tmp_c_door_tt_id, c_door_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Closed Door" end)
    assert {tmp_o_door_tt_id, o_door_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Open Door" end)
    assert {tmp_fireball_tt_id, fireball_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Fireball" end)
    assert {tmp_explosion_tt_id, explosion_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Explosion" end)
    assert {tmp_stone_tt_id, stone_tt} = Enum.find(tile_templates, fn {_, tile} -> tile.name == "Stone" end)

    assert floor_tt.name == export.basic_tiles.floor.name
    assert wall_tt.name == export.basic_tiles.wall.name
    assert rock_tt.name == export.basic_tiles.rock.name
    assert c_door_tt.name == export.basic_tiles.closed_door.name
    assert o_door_tt.name == export.basic_tiles.open_door.name
    assert fireball_tt.name == export.basic_tiles.fireball.name
    assert explosion_tt.name == export.basic_tiles.explosion.name
    assert stone_tt.name == export.basic_tiles.stone.name

    assert comp_tt_fields(export.basic_tiles.floor) == comp_tt_fields(floor_tt)
    assert comp_tt_fields(export.basic_tiles.wall) == comp_tt_fields(wall_tt)
    assert comp_tt_fields(export.basic_tiles.rock) == comp_tt_fields(rock_tt)
    assert comp_tt_fields(export.basic_tiles.closed_door) == comp_tt_fields(c_door_tt)
    assert comp_tt_fields(export.basic_tiles.open_door) == comp_tt_fields(o_door_tt)
    assert comp_tt_fields(export.basic_tiles.fireball) == comp_tt_fields(fireball_tt)
    assert comp_tt_fields(export.basic_tiles.explosion) == comp_tt_fields(explosion_tt)
    assert comp_tt_fields(export.basic_tiles.stone) == comp_tt_fields(stone_tt)
    assert %{temp_tt_id: ^tmp_floor_tt_id} = floor_tt
    assert %{temp_tt_id: ^tmp_wall_tt_id} = wall_tt
    assert %{temp_tt_id: ^tmp_rock_tt_id} = rock_tt
    assert %{temp_tt_id: ^tmp_c_door_tt_id} = c_door_tt
    assert %{temp_tt_id: ^tmp_o_door_tt_id} = o_door_tt
    assert %{temp_tt_id: ^tmp_fireball_tt_id} = fireball_tt
    assert %{temp_tt_id: ^tmp_explosion_tt_id} = explosion_tt
    assert %{temp_tt_id: ^tmp_stone_tt_id} = stone_tt

    # Item scripts
    assert gun.script == """
      #take ammo, 1, ?self, error
      #shoot @facing
      #sound #{ tmp_shoot_id }
      #end
      :error
      Out of ammo!
      #sound #{ tmp_click_id }
      """
    assert wand.script == """
      #put direction: here, slug: #{ tmp_fireball_tt_id }, facing: @facing, owner: ?self
      #take gems, 1, ?self, it_might_break
      #end
      :it_might_break
      #if ?random@10 != 10, 1
      #end
      The wand broke!
      #if ?random@4 != 4, 2
      #put slug: #{ tmp_explosion_tt_id }, shape: circle, range: 3, damage: 10, owner: ?self
      #sound #{ tmp_bomb_id }
      #die
      """
    assert stone.script == """
      #put direction: here, slug: #{ tmp_stone_tt_id }, facing: @facing, thrown: true
      """

    # Tile template scripts
    assert floor_tt.script == ""
    assert wall_tt.script == ""
    assert rock_tt.script == ""
    assert c_door_tt.script == "#END\n:OPEN\n#SOUND #{ tmp_door_id }\n#BECOME slug: #{ tmp_o_door_tt_id }"
    assert o_door_tt.script == "#END\n:CLOSE\n#SOUND #{ tmp_door_id }\n#BECOME slug: #{ tmp_c_door_tt_id }"
    assert fireball_tt.script == """
      :MAIN
      #WALK @facing
      :THUD
      #SOUND #{ tmp_bomb_id }
      #PUT slug: #{ tmp_explosion_tt_id }, shape: circle, range: 2, damage: 10, owner: @owner
      #DIE
      """
    assert explosion_tt.script == """
      #SEND bombed, here
      :TOP
      #RANDOM c, red, orange, yellow
      #BECOME color: @c
      ?i
      @count -= 1
      #IF @count > 0, top
      #DIE
      """
    assert stone_tt.script == """
      #if @thrown, thrown
      :main
      #end
      :touch
      #if ! ?sender@player, main
      Picked up a stone
      #equip #{ tmp_stone_id }, ?sender
      #sound #{ tmp_pickup_blip_id }, ?sender
      #die
      :thrown
      #zap touch
      @flying = true
      #walk @facing
      :thud
      :touch
      @flying=false
      #restore thrown
      #restore touch
      #send shot, ?sender
      #send main
      """

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
           |> Map.put(:script, "#END\n:OPEN\n#SOUND #{tmp_door_id}\n#BECOME slug: #{tmp_o_door_tt_id}" )
           == Map.delete(c_door, :tile_template_id)
    assert Map.merge(Dungeons.copy_tile_fields(export.basic_tiles.floor), %{state: %{"light_source" => true}, name: "Floor 2"}) == Map.delete(floor2, :tile_template_id)
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
    assert [] == level_1_tile_data

    assert %{entrance: true,
             height: 20,
             width: 20,
             name: "one",
             number: 2,
             number_north: 3,
             tile_data: level_2_tile_data} = level_2
    assert [
             [floor_hash, 0, 1, 0],
             [rock_hash, 0, 2, 0],
             [floor_hash, 0, 3, 0],
             [floor_hash, 1, 1, 0],
             [c_door_hash, 1, 2, 0],
             [floor_hash, 1, 3, 0],
             [wall_hash, 2, 1, 0],
             [wall_hash, 2, 2, 0],
             [wall_hash, 2, 3, 0]
           ] == level_2_tile_data

    assert %{entrance: nil,
             height: 20,
             width: 20,
             name: "Stubbed",
             number: 3,
             state: %{"visibility" => "fog"},
             tile_data: level_3_tile_data} = level_3
    assert [
             [floor_hash, 0, 1, 0],
             [floor_hash, 0, 2, 0],
             [floor2_hash, 1, 1, 0],
             [custom_hash, 1, 2, 1]
           ] == level_3_tile_data

    # spawn locations
    assert [[2, 0, 1], [2, 0, 3], [3, 1, 1]] == spawn_locations

    # Dungeon
    assert Map.drop(dungeon, [:state, :user_name]) == Map.drop(Dungeons.copy_dungeon_fields(export.dungeon), [:state, :user_id])
    assert dungeon.state["starting_equipment"] == [gun.temp_item_id, wand.temp_item_id]

    # verify the whole export
    # the temp ids may be different, depending on how stuff gets sorted / encountered when sto'ing assets
    assert DungeonCrawlWeb.ExportFixture.export == export_hash
  end

  test "run/1 dungeon without starting_equipment", export do
    {:ok, updated_dungeon} = Dungeons.update_dungeon(export.dungeon, %{state: %{"foo" => "bar"}})
    Dungeons.delete_level!(export.level_2)
    Dungeons.delete_level!(export.level_3)

    export_hash = DungeonExports.run(updated_dungeon.id)

    assert %DungeonExports{
             dungeon: dungeon,
             items: items,
             spawn_locations: spawn_locations,
           } = export_hash

    assert [{tmp_gun_id, gun}] = Map.to_list(items)

    assert Map.delete(Equipment.copy_fields(export.items.gun), :script)
           == Map.drop(gun, [:temp_item_id, :script])
    assert %{temp_item_id: ^tmp_gun_id} = gun

    assert [] == spawn_locations

    assert Map.delete(dungeon, :user_name) == Map.delete(Dungeons.copy_dungeon_fields(updated_dungeon), :user_id)
  end

  @tag timeout: 5_000
  test "when a script references an item which references itself" do
    {:ok, equipment_tile} = TileTemplates.create_tile_template(%{
      name: "Bread Maker",
      description: "it makes bread",
      character: "x",
      active: true
    })
    {:ok, equipment_item} = Equipment.create_item(%{
      slug: "bread_maker",
      name: "Bread Maker",
      description: "put this somewhere it can make bread",
      script: """
              #replace target: @facing, slug: #{ equipment_tile.slug }
              #unequip bread_maker, ?self
              """
    })
    gives_item_tile = %{
      name: "",
      character: "x",
      state: %{"blocking" => true},
      script: "#end\n:touch\n#equip #{equipment_item.slug}, ?sender",
      row: 1,
      col: 3,
      z_index: 0
    }
    dungeon  = insert_stubbed_dungeon(%{state: %{starting_equipment: []}}, %{}, [[gives_item_tile]])

    # This will also raise a timeout error if the export gets stuck in an infinite
    # recursive loop while exporting
    export_hash = DungeonExports.run(dungeon.id)

    assert %DungeonExports{
             levels: levels,
             tiles: tiles,
             items: items,
             tile_templates: tile_templates,
           } = export_hash


    # Items
    assert [{tmp_item_bread_maker_id, item_bread_maker}] = Map.to_list(items)

    assert comp_item_fields(equipment_item) == comp_item_fields(item_bread_maker)
    assert %{temp_item_id: ^tmp_item_bread_maker_id} = item_bread_maker

    # Tile templates
    assert [{tmp_bm_tt_id, bm_tt}] = Map.to_list(tile_templates)

    assert bm_tt.name == equipment_tile.name

    assert comp_tt_fields(equipment_tile) == comp_tt_fields(bm_tt)
    assert %{temp_tt_id: ^tmp_bm_tt_id} = bm_tt

    # Item scripts
    assert item_bread_maker.script == """
           #replace target: @facing, slug: #{ tmp_bm_tt_id }
           #unequip #{ tmp_item_bread_maker_id }, ?self
           """

    # Tiles
    assert [{gives_item_hash, gives_item}] = Map.to_list(tiles)

    assert Map.take(gives_item_tile, [:character, :name, :script, :state])
           |> Map.put(:script, "#end\n:touch\n#equip #{tmp_item_bread_maker_id}, ?sender" )
           == Map.take(gives_item, [:character, :name, :script, :state])

    assert is_nil(gives_item.tile_template_id)

    # Levels
    assert %{1 => level_1} = levels
    assert length(Map.keys(levels)) == 1

    assert %{tile_data: level_1_tile_data} = level_1
    assert [[gives_item_hash, 1, 3, 0]] == level_1_tile_data
  end

  def comp_item_fields(item) do
    Equipment.copy_fields(item)
    |> Map.drop([:temp_item_id, :script])
  end

  def comp_tt_fields(tt) do
    TileTemplates.copy_fields(tt)
  |> Map.drop([:temp_tt_id, :script])
  end
end

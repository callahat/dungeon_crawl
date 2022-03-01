defmodule DungeonCrawl.Shipping.DungeonImportsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports
  alias DungeonCrawl.Shipping.DungeonImports

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.{TileSeeder, TileTemplate}

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
    {:ok, click} = Sound.Seeder.click()
                   |> Sound.update_effect(%{public: false})
    shoot = Sound.Seeder.shoot()
    sounds = %{alarm: alarm, click: click, pickup_blip: pickup_blip, shoot: shoot}

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

  test "run/1", config do
    user_id = config.user.id

    tile_template_count = Enum.count(TileTemplates.list_tile_templates())
    sound_count = Enum.count(Sound.list_effects())
    item_count = Enum.count(Equipment.list_items())

    # what was created in setup
    assert tile_template_count == 2
    assert sound_count == 4
    assert item_count == 2

    assert %DungeonExports{
             dungeon: dungeon,
             tile_templates: tile_templates,
             tiles: tiles
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
    assert config.sounds.click == Sound.get_effect_by_slug("click") # not public, so cannot be used
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
    # the click used was not public, so the seeded gun could not be used
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
    assert {floor_hash, floor_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor" end)
    assert {wall_hash, wall_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Wall" end)
    assert {rock_hash, rock_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Rock" end)
    assert {c_door_hash, c_door_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Closed Door" end)
    assert {floor2_hash, floor2_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "Floor 2" end)
    assert {custom_hash, custom_tile} = Enum.find(tiles, fn {_, tile} -> tile.name == "" end)

    assert Map.take(floor_tile, [:tile_template_id, :script])
           == %{tile_template_id: floor.id, script: ""}
    assert Map.take(wall_tile, [:tile_template_id, :script])
           == %{tile_template_id: wall.id, script: ""}
    assert Map.take(rock_tile, [:tile_template_id, :script])
           == %{tile_template_id: config.existing_tiles.rock.id, script: ""}
    assert Map.take(c_door_tile, [:tile_template_id, :script])
           == %{tile_template_id: closed_door.id,
                script: "#END\n:OPEN\n#BECOME slug: #{open_door.slug}\n#SOUND #{door.slug}"}
    assert Map.take(floor2_tile, [:tile_template_id, :script, :state])
           == %{tile_template_id: floor.id, state: "light_source: true", script: ""}
    assert Map.take(custom_tile, [:tile_template_id, :script])
           == %{tile_template_id: nil,
             script: "#end\n:touch\n#sound #{config.sounds.alarm.slug}\n#equip #{config.items.stone.slug}, ?sender\n#become slug: #{wall.slug}\n#unequip #{gun.slug}, ?sender\n/i\n#sound #{config.sounds.alarm.slug}"}

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
    assert closed_door.script == "#END\n:OPEN\n#BECOME slug: #{ open_door.slug }\n#SOUND #{ door.slug }"
    assert open_door.script == "#END\n:CLOSE\n#BECOME slug: #{ closed_door.slug }\n#SOUND #{ door.slug }"
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
    dungeon_state = "test: true, starting_equipment: #{ gun.slug } #{ wand.slug }"
    assert %{
      autogenerated: false,
      default_map_height: 20,
      default_map_width: 20,
      description: "testing",
      line_identifier: 1,
      name: "Exporter",
      state: ^dungeon_state,
      title_number: 2,
      user_id: user_id} = dungeon
    assert dungeon == Dungeons.get_dungeon!(dungeon.id)

    # verify level records and their details
    raise "verify level records and their deets"
  end

  defp _exported_tt(export_hash, asset_name) do
    _exported(export_hash, :tile_templates, asset_name)
  end

  defp _exported(export_hash, asset_key, asset_name) do
    {_, asset} =
    Map.get(export_hash, asset_key)
    |> Enum.find(fn {_temp_id, attrs} -> attrs[:name] == asset_name end)

    asset
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
end

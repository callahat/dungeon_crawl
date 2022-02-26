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
    # todo: verify fireball wand craeted
    items = %{gun: gun, stone: stone}

    alarm = Sound.Seeder.alarm()
    # todo: verify door sound crated
    sounds = %{alarm: alarm}

    rock = TileSeeder.rock_tile()

    # todo: verify all other tts created; floor, wall, closed_door and open_door
    existing_tiles = %{rock: rock}

    user = insert_user()

    # Reusing the setup from DungeonExport, and then exporting that for the test dump is significantly less
    # lines. Additionally, the two modules are meant to be somewhat tightly coupled; the import
    # takes the output of the export. So this also has the benifit of likely noticably breaking
    # should the contract change with one and not the other.
    export_hash = DungeonCrawlWeb.ExportFixture.export

    # todo: any config that deletes

    %{export_hash: export_hash, user: user, sounds: sounds, items: items, existing_tiles: existing_tiles}
  end

  test "run/1", config do
    tile_template_count = Enum.count(TileTemplates.list_tile_templates())
    sound_count = Enum.count(Sound.list_effects())
    item_count = Enum.count(Equipment.list_items())

    # what was created in setup
    assert tile_template_count == 1
    assert sound_count == 1
    assert item_count == 2

    DungeonImports.run(config.export_hash, config.user.id)

    assert 3 == Enum.count(TileTemplates.list_tile_templates()) - tile_template_count
    assert 1 == Enum.count(Sound.list_effects()) - sound_count
    assert 1 == Enum.count(Equipment.list_items()) - item_count

    # assets created or found
    # tile templates
    assert config.existing_tiles.rock == TileTemplates.get_tile_template_by_slug("rock")
    assert floor = TileTemplates.get_tile_template_by_slug("floor")
    assert closed_door = TileTemplates.get_tile_template_by_slug("closed_door")
    assert open_door = TileTemplates.get_tile_template_by_slug("open_door")
    assert wall = TileTemplates.get_tile_template_by_slug("floor")

    assert TileTemplates.copy_fields(floor) ==
             Map.delete(config.export_hash.tile_templates["tmp_tt_id_0"], :temp_tt_id)
    assert TileTemplates.copy_fields(closed_door) ==
             Map.delete(config.export_hash.tile_templates["tmp_tt_id_2"], :temp_tt_id)
    assert TileTemplates.copy_fields(open_door) ==
             Map.delete(config.export_hash.tile_templates["tmp_tt_id_3"], :temp_tt_id)
    assert TileTemplates.copy_fields(wall) ==
             Map.delete(config.export_hash.tile_templates["tmp_tt_id_4"], :temp_tt_id)


    # sounds effects

    # items
    assert TileTemplates.get_tile_template_by_slug(_exported_tt(config.export_hash, "Closed Door"))
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
end

defmodule DungeonCrawl.Shipping.DungeonImportsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports
  alias DungeonCrawl.Shipping.DungeonImports

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Sound
  alias DungeonCrawl.TileTemplates
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
    basic_tiles = %{rock: rock}

    user = insert_user()

    # Reusing the setup from DungeonExport, and then exporting that for the test dump is significantly less
    # lines. Additionally, the two modules are meant to be somewhat tightly coupled; the import
    # takes the output of the export. So this also has the benifit of likely noticably breaking
    # should the contract change with one and not the other.
    export_hash = DungeonCrawlWeb.ExportFixture.export

    # todo: any config that deletes

    %{export_hash: export_hash, user: user, sounds: sounds, items: items, basic_tiles: basic_tiles}
  end

  test "run/1", export do

  end
end

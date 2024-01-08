defmodule DungeonCrawl.Shipping.Private.ImportFunctionsTest do
  use DungeonCrawl.DataCase

  import DungeonCrawl.Shipping.Private.ImportFunctions

  alias DungeonCrawl.TileTemplates.TileSeeder, as: TileTemplateSeeder
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder

  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.Sound
  alias DungeonCrawl.StateValue.Parser

  alias DungeonCrawlWeb.ExportFixture

  alias DungeonCrawl.Shipping.DungeonExports

  require DungeonCrawl.SharedTests

  # TODO: for each of these functions make sure to assert and check the significant changes to export;
  # some will change a whole node after looking up a record but that may not be significant
  # as some functions, such as repoint, only care about the ID and new slug that was added
  # when they change data related to their operation (such as changing a temporary tile template id
  # from "tmp_..." to the record ID from the backing database.

  describe "find_or_create_assets/3" do
    setup config do
      existing_asset = Map.get(ExportFixture.minimal_export(), config.asset_key)[config.key]

      existing_asset = if config.asset_key == :items,
                          # for these tests we don't care about matching on this
                         do: Map.put(existing_asset, :script, "#end"),
                         else: existing_asset

      export = %DungeonExports{}
               |> Map.put(config.asset_key, %{
                    config.key => existing_asset
                  })

      %{export: export}
    end

    DungeonCrawl.SharedTests.finds_or_creates_assets_correctly(
      :items, "tmp_item_id_0", &insert_item/1, &Equipment.copy_fields/1)

    DungeonCrawl.SharedTests.finds_or_creates_assets_correctly(
      :tile_templates, "tmp_tt_id_0", &insert_tile_template/1, &TileTemplates.copy_fields/1)

    DungeonCrawl.SharedTests.finds_or_creates_assets_correctly(
      :sounds, "tmp_sound_id_0", &insert_effect/1, &Sound.copy_fields/1)
  end

  describe "find_effect/2" do
    test "finds the effect, user id impacts nothing" do
      user_id = "not_used"
      click = SoundSeeder.click()

      attrs = Map.take(click, [:name, :public, :user_id, :zzfx_params, :slug])

      assert click == find_effect(user_id, attrs)
      assert find_effect(user_id, attrs) == find_effect(nil, attrs)
      refute find_effect(user_id, %{ attrs | name: "different" <> click.name})
    end
  end

  describe "find_item/2" do
    test "an existing public item can be used" do
      user = insert_user()
      potion = EquipmentSeeder.levitation_potion()

      attrs = Equipment.copy_fields(potion)
      assert potion == find_item(user.id, attrs)
    end

    test "an existing private item owned by someone else" do
      user = insert_user()
      user2 = insert_user(%{user_id_hash: "other"})
      item = insert_item(%{user_id: user2.id, public: false})

      attrs = Equipment.copy_fields(item)
      # right now, no checks happen to see if a slug belongs to someone else for a match
      assert item == find_item(user.id, attrs)
    end

    test "an existing item owned by importer" do
      user = insert_user()
      tile = insert_item(%{user_id: user.id})

      attrs = Equipment.copy_fields(tile)
      assert tile == find_item(user.id, attrs)
    end

    test "a nonexistant item" do
      user = insert_user()

      attrs = %{name: "non existant", script: "HI"}

      refute find_item(user.id, attrs)
    end

    test "an item with a script referencing a nonexistant asset slug" do
      user = insert_user()
      tile = insert_item(%{public: true, script: "#become slug: clay"})

      attrs = Equipment.copy_fields(tile)
      refute find_item(user.id, attrs)
    end
  end

  describe "find_tile_template/2" do
    test "an existing public template can be used" do
      user = insert_user()
      bandit = TileTemplateSeeder.bandit()
      misorderd_state = Enum.map(bandit.state, fn {k,v} -> "#{k}: #{v}" end)
                        |> Enum.reverse()
                        |> Enum.join(", ")

      # a bug existed where when it compared the state strings, they were equivalent
      # but not in the same order causing a miss when it should have matched
      # This ensures the order of the state string is different from the order used by
      # the custom Ecto Type
      Ecto.Adapters.SQL.query!(DungeonCrawl.Repo,
        "UPDATE tile_templates SET state = '#{misorderd_state}' WHERE id = #{bandit.id}", [])

      # smoke check that the state strings don't match at least in order
      [[stored_state]] =
        Ecto.Adapters.SQL.query!(
          DungeonCrawl.Repo,
          "SELECT state from tile_templates WHERE id = #{bandit.id}").rows
      refute Parser.stringify(bandit.state) == stored_state
      assert String.length(Parser.stringify(bandit.state)) == String.length(stored_state)

      # the actual tests
      attrs = TileTemplates.copy_fields(bandit)
      assert bandit == find_tile_template(user.id, attrs)

      # slightly different state causes a miss
      Ecto.Adapters.SQL.query!(DungeonCrawl.Repo,
        "UPDATE tile_templates SET state = '#{misorderd_state}, different: yes' WHERE id = #{bandit.id}", [])

      refute find_tile_template(user.id, attrs)
    end

    test "an existing template that is private and someone elses" do
      user = insert_user()
      user2 = insert_user(%{user_id_hash: "other"})
      tile = insert_tile_template(%{user_id: user2.id, public: false})

      attrs = TileTemplates.copy_fields(tile)
      # right now, no checks happen to see if a slug belongs to someone else for a match
      assert tile == find_tile_template(user.id, attrs)
    end

    test "an existing template owned by importer" do
      user = insert_user()
      tile = insert_tile_template(%{user_id: user.id})

      attrs = TileTemplates.copy_fields(tile)
      assert tile == find_tile_template(user.id, attrs)
    end

    test "a template that does not exist" do
      user = insert_user()

      attrs = %{
        name: "non existant",
        script: "",
        description: nil,
        character: nil,
        slug: "banana",
        user_id: nil,
        group_name: "custom"
      }

      refute find_tile_template(user.id, attrs)
    end

    test "a template with a script refering to a slug that does not exist" do
      user = insert_user()
      tile = insert_tile_template(%{public: true, active: true, script: "#become slug: clay"})

      attrs = TileTemplates.copy_fields(tile)
      refute find_tile_template(user.id, attrs)
    end
  end

  describe "script_fuzzer/1" do
    test "replaces slugs with <FUZZ> for equivalent comparision purposes" do
      script = """
      #become character: X, slug: tmp_tt_id_1
      #become slug: tmp_tt_id_1, color: mauve
      #equip bacon, ?sender
      #unequip rocks, ?sender, label
      #sound boom
      """

      expected_script = """
      #become character: X, slug: <FUZZ>
      #become slug: <FUZZ>, color: mauve
      #equip <FUZZ>, ?sender
      #unequip <FUZZ>, ?sender, label
      #sound <FUZZ>
      """

      assert expected_script == script_fuzzer(script)
    end
  end

  describe "all_slugs_useable?/2" do
    test "all slugs are useable (they exist)" do
      bandit = TileTemplateSeeder.bandit()
      click = SoundSeeder.click()
      potion = EquipmentSeeder.levitation_potion()

      script = """
      #equip #{potion.slug}, ?sender
      #sound #{click.slug}
      #become slug: #{bandit.slug}
      """

      assert all_slugs_useable?(script, 1)
    end

    test "no slugs in the script" do
      assert all_slugs_useable?(nil, 1)
      assert all_slugs_useable?("#become color: red", 1)
    end

    test "a sound slug is not usable" do
      refute all_slugs_useable?("#sound bong", 1)
    end

    test "an item slug is not usable" do
      refute all_slugs_useable?("#equip rock", 1)
    end

    test "a tile template slug is not usable" do
      refute all_slugs_useable?("#become slug: door", 1)
    end

    test "some slugs are usable, some are not" do
      bandit = TileTemplateSeeder.bandit()

      script = """
      #equip slab_of_bacon, ?sender
      #become slug: #{bandit.slug}
      """

      refute all_slugs_useable?(script, 1)
    end
  end

  describe "repoint_ttids_and_slugs/2" do
    setup do
      # The functions called before this one in the importer
#      export
#      |> find_or_create_assets(:sounds, &find_effect/2, &Sound.create_effect!/1, user_id)
#      |> find_or_create_assets(:items, &find_item/2, &Equipment.create_item!/1, user_id)
#      |> find_or_create_assets(:tile_templates, &find_tile_template/2, &TileTemplates.create_tile_template!/1, user_id)
#      |> swap_scripts_to_tmp_scripts(:tiles)
      user = insert_user()
      rock_tt = insert_tile_template(%{
        name: "Rock",
        state: %{"blocking" => true},
        public: true,
        active: true
      })
      stone_tt = insert_tile_template(%{
                     name: "Stone",
                     script: "#end",
                     public: true,
                     active: true
                   })
                 |> Map.put(:script, "#end")
                 |> Map.put(:tmp_script, "#end\n:touch\n#equip tmp_item_id_1, ?sender\n#die")
      stone_item = insert_item(%{
                       user_id: user.id,
                       name: "Stone",
                       script: "#end"
                     })
                   |> Map.put(:script, "#end")
                   |> Map.put(:tmp_script, "#put direction: here, slug: tmp_tt_id_1, facing: @facing, thrown: true\n")

      expected = %{
        click_slug: "click",
        rock_tt_id: rock_tt.id,
        rock_tt_slug: "rock",
        stone_tt_slug: stone_tt.slug,
        stone_item_slug: stone_item.slug,
        thing_script: ""
      }

      export_mock =
      %DungeonExports{
        tile_templates: %{
          "tmp_tt_id_0" => rock_tt,
          "tmp_tt_id_1" => stone_tt
        },
        sounds: %{
          "tmp_sound_id_0" => %{id: 900, slug: expected.click_slug},
          "tmp_sound_id_1" => %{id: 998, slug: "blip"},
          "tmp_sound_id_2" => %{id: 999, slug: "shoot"}
        },
        items: %{
          "tmp_item_id_1" => stone_item
        },
        tiles: %{
          "rock_hash" => %{
            script: "",
            tile_template_id: "tmp_tt_id_0"
          },
          "thing_hash" => %{
            script: "#end",
            tmp_script: "#end\n:touch\n#sound tmp_sound_id_0\n#equip tmp_item_id_1, ?sender\n#become slug: tmp_tt_id_0",
            tile_template_id: nil
          }
        }
      }

     %{ export: export_mock, expected: expected }
    end

    test "repoints tiles", %{export: export, expected: expected} do
      updated_export = repoint_ttids_and_slugs(export, :tiles)

      # only changes the given asset
      assert Map.drop(updated_export, [:tiles]) == Map.drop(export, [:tiles])

      %DungeonExports{
        tiles: %{
          "rock_hash" => updated_rock,
          "thing_hash" => updated_thing
        }
      } = updated_export

      assert updated_rock.tile_template_id == expected.rock_tt_id
      assert updated_rock.script == ""

      assert updated_thing.tile_template_id == nil
      assert updated_thing.script ==
               "#end\n:touch\n#sound #{ expected.click_slug }\n#equip #{ expected.stone_item_slug }, ?sender\n#become slug: #{ expected.rock_tt_slug }"
    end

    test "repoints items", %{export: export, expected: expected} do
      updated_export = repoint_ttids_and_slugs(export, :items)

      # only changes the given asset
      assert Map.drop(updated_export, [:items]) == Map.drop(export, [:items])

      %DungeonExports{
        items: %{
          "tmp_item_id_1" => stone_item
        }
      } = updated_export

      assert stone_item.script ==
               "#put direction: here, slug: #{ expected.stone_tt_slug }, facing: @facing, thrown: true\n"
      assert Repo.reload(stone_item).script == stone_item.script
    end

    test "repoints tile_templates", %{export: export, expected: expected} do
      updated_export = repoint_ttids_and_slugs(export, :tile_templates)

      # only changes the given asset
      assert Map.drop(updated_export, [:tile_templates]) == Map.drop(export, [:tile_templates])

      %DungeonExports{
        tile_templates: %{
          "tmp_tt_id_0" => rock_tt,
          "tmp_tt_id_1" => stone_tt
        }
      } = updated_export

      # nothing changed for rock tile template
      assert rock_tt == export.tile_templates["tmp_tt_id_0"]
      # update stone script
      assert stone_tt.script == "#end\n:touch\n#equip #{ expected.stone_item_slug }, ?sender\n#die"
      assert Repo.reload(stone_tt).script == stone_tt.script
    end
  end

  describe "repoint_tile_template_id/2" do
    test "repoints the tile_template_id" do
      export = %DungeonExports{tile_templates: %{"tmp_tt_id_0" => %{id: 500}}}
      asset = %{tile_template_id: "tmp_tt_id_0"}
      updated_asset = repoint_tile_template_id(asset, export)
      assert updated_asset.tile_template_id == 500
    end

    test "does nothing if the asset does not have a tile_template_id" do
      export = %DungeonExports{tile_templates: %{"tmp_tt_id_0" => %{id: 500}}}
      asset = %{tile_template_id: nil}
      updated_asset = repoint_tile_template_id(asset, export)
      refute updated_asset.tile_template_id
    end
  end

  describe "swap_scripts_to_tmp_scripts/2" do
    # this function is only used for :tiles
    test "it puts the script into tmp_script" do
      export = %DungeonExports{
        tiles: %{"tile_hash" => %{script: "#end\n:touch\nhey"}},
        items: %{"tmp_item_0" => %{script: "does nothing"}}
      }

      updated_export = swap_scripts_to_tmp_scripts(export, :tiles)
      assert Map.delete(updated_export, :tiles) == Map.delete(export, :tiles)
      assert %{script: "#end\n:touch\nhey",
               tmp_script: "#end\n:touch\nhey"} = updated_export.tiles["tile_hash"]
    end
  end

  describe "repoint_dungeon_starting_items/1" do
    test "does nothing if no starting equipment" do
      export = %DungeonExports{ dungeon: %{ state: %{} }, items: %{"tmp_item_id_0" => %{slug: "thing"}} }
      assert export == repoint_dungeon_starting_items(export)
    end

    test "replaces temp ids with found or created item slugs" do
      export = %DungeonExports{
        dungeon: %{state: %{"starting_equipment" => ["tmp_item_id_0", "tmp_item_id_0", "tmp_item_id_1"]}},
        items: %{"tmp_item_id_0" => %{slug: "thing"}, "tmp_item_id_1" => %{slug: "waffle"}}}

      %{dungeon: %{state: %{"starting_equipment" => updated_starting_items}}} =
        repoint_dungeon_starting_items(export)

      assert ["thing", "thing", "waffle"] == updated_starting_items
    end
  end

  describe "set_dungeon_overrides/3" do
    setup do
      export =
        %DungeonExports{
          tile_templates: "stubbed",
          sounds: "stubbed",
          items: "stubbed",
          tiles: "stubbed",
          dungeon: %{
            description: "testing",
            line_identifier: 1,
            user_name: "Some User",
            user_id: 999
          }
        }

      %{export: export}
    end

    test "sets the line identifier, user_id, and importing", %{export: export} do
      updated_export = set_dungeon_overrides(export, 123, "9")

      assert Map.delete(updated_export, :dungeon) == Map.delete(export, :dungeon)

      assert updated_export.dungeon.user_id == 123
      assert updated_export.dungeon.line_identifier == "9"
      assert updated_export.dungeon.importing
      refute Map.has_key?(updated_export.dungeon, :user_name)
    end

    test "sets line identifier to nil if empty string", %{export: export} do
      updated_export = set_dungeon_overrides(export, 123, "")
      refute updated_export.dungeon.line_identifier

      updated_export = set_dungeon_overrides(export, 123, nil)
      refute updated_export.dungeon.line_identifier
    end
  end

  describe "maybe_handle_previous_version/1" do
    setup do
      user = insert_user()
      dungeon = insert_dungeon(%{line_identifier: 500, version: 9, active: true, user_id: user.id})

      %{dungeon: dungeon, user: user}
    end

    test "nils line_identifier if no previous dungeon found", %{dungeon: dungeon, user: user} do
      export = %DungeonExports{dungeon: %{line_identifier: -1, user_id: user.id}}
      assert %{dungeon: %{line_identifier: nil}} = maybe_handle_previous_version(export)

      # user_id in the export has been replaced with the user_id of the current user's id
      # as this ID may be different on different installations
      export = %DungeonExports{dungeon: %{line_identifier: dungeon.line_identifier, user_id: user.id - 1}}
      assert %{dungeon: %{line_identifier: nil}} = maybe_handle_previous_version(export)
    end

    test "if previous version is active, updates the dungeon attrs in the export", %{dungeon: dungeon, user: user} do
      export = %DungeonExports{dungeon: %{line_identifier: dungeon.line_identifier, user_id: user.id}}
      %{dungeon: updated_dungeon_attrs} = maybe_handle_previous_version(export)

      refute updated_dungeon_attrs.active
      assert updated_dungeon_attrs.line_identifier == dungeon.line_identifier
      assert updated_dungeon_attrs.previous_version_id == dungeon.id
      assert updated_dungeon_attrs.version == dungeon.version + 1
      assert Dungeons.get_dungeon(dungeon.id)
    end

    test "if previous version is not active, that dungeon is hard deleted", %{dungeon: dungeon, user: user} do
      {:ok, dungeon} = Dungeons.update_dungeon(dungeon, %{active: false})
      export = %DungeonExports{dungeon: %{line_identifier: dungeon.line_identifier, user_id: user.id}}
      %{dungeon: updated_dungeon_attrs} = maybe_handle_previous_version(export)

      refute updated_dungeon_attrs.active
      assert updated_dungeon_attrs.line_identifier == dungeon.line_identifier
      assert updated_dungeon_attrs.previous_version_id == dungeon.previous_version_id
      assert updated_dungeon_attrs.version == dungeon.version
      refute Dungeons.get_dungeon(dungeon.id)
    end
  end

  describe "create_dungeon/1" do
    test "it creates the dungeon" do
      user = insert_user()
      item = insert_item()
      export = %DungeonExports{
        dungeon: %{
          autogenerated: false,
          default_map_height: 20,
          default_map_width: 20,
          description: "testing",
          line_identifier: 999,
          name: "Exporter",
          state: %{"starting_equipment" => [item.slug], "test" => true},
          title_number: 2,
          user_id: user.id,
          importing: true,
          previous_version_id: nil
        },
      }

      updated_export = create_dungeon(export)
      expected_dungeon =  Map.merge(%Dungeons.Dungeon{importing: true}, Dungeons.copy_dungeon_fields(export.dungeon))

      assert Map.drop(expected_dungeon, [:__meta__, :id, :inserted_at, :updated_at]) ==
               Map.drop(updated_export.dungeon, [:__meta__, :id, :inserted_at, :updated_at])

      assert is_integer(updated_export.dungeon.id)
    end
  end

  describe "create_levels/1" do
    setup do
      dungeon = insert_dungeon()
      floor = insert_tile_template(%{character: ".", state: %{"blocking" => false}, description: "a dirty floor", name: "Floor"})
      rock = TileTemplateSeeder.rock_tile()

      export = %DungeonExports{
        dungeon: dungeon,
        levels: %{
          1  => %{
            entrance: true,
            height: 20,
            name: "one",
            number: 1,
            number_east: nil,
            number_north: 3,
            number_south: nil,
            number_west: nil,
            state: %{},
            tile_data: [
              ["rock_hash", 0, 1, 0],
              ["floor_hash", 0, 2, 0],
              ["rock_hash", 0, 3, 0]
            ],
            width: 20
          },
          2 => %{
            entrance: nil,
            height: 20,
            name: "Stubbed",
            number: 2,
            number_east: nil,
            number_north: nil,
            number_south: nil,
            number_west: nil,
            state: %{"visibility" => "fog"},
            tile_data: [
              ["rock_hash", 0, 1, 0],
              ["floor_hash", 0, 2, 0],
              ["floor_hash", 1, 1, 0],
              ["lamp_hash", 1, 2, 1]
            ],
            width: 20
          }
        },
        tiles: %{
          "rock_hash" => %{
            animate_background_colors: nil,
            animate_characters: nil,
            animate_colors: nil,
            animate_period: nil,
            animate_random: nil,
            background_color: nil,
            character: " ",
            color: nil,
            name: "Rock",
            script: "",
            state: %{"blocking" => true},
            tile_template_id: rock.id
          },
          "lamp_hash" => %{
            animate_background_colors: nil,
            animate_characters: nil,
            animate_colors: nil,
            animate_period: nil,
            animate_random: nil,
            background_color: nil,
            character: "i",
            color: nil,
            name: "Lamp",
            script: "",
            state: %{"light_source" => true},
            tile_template_id: nil
          },
          "floor_hash" => %{
            animate_background_colors: nil,
            animate_characters: nil,
            animate_colors: nil,
            animate_period: nil,
            animate_random: nil,
            background_color: nil,
            character: ".",
            color: nil,
            name: "Floor",
            script: "",
            state: %{"blocking" => false},
            tile_template_id: floor.id
          }
        }
      }

      %{export: export, dungeon: dungeon}
    end

    test "it creates the levels and their tiles", %{export: export, dungeon: dungeon} do
      updated_export = create_levels(export)
      dungeon_id = dungeon.id

      # the tiles hash is not updated in the export
      assert Map.drop(updated_export, [:levels]) == Map.drop(export, [:levels])
      assert %{levels: updated_levels} = updated_export
      %{1 => updated_level_1, 2 => updated_level_2} = updated_levels
      assert Kernel.map_size(updated_levels) == 2
      assert %Dungeons.Level{
               dungeon_id: ^dungeon_id,
               state: %{}
             } = updated_level_1
      assert %Dungeons.Level{
               dungeon_id: ^dungeon_id,
               state: %{"visibility" => "fog"}
             } = updated_level_2

      # but the tiles are created in the DB
      [%{name: "Rock"}] = Dungeons.get_tiles(updated_level_1.id, 0, 1)
      [%{name: "Floor"}] = Dungeons.get_tiles(updated_level_1.id, 0, 2)
      [%{name: "Rock"}] = Dungeons.get_tiles(updated_level_1.id, 0, 3)

      [%{name: "Rock"}] = Dungeons.get_tiles(updated_level_2.id, 0, 1)
      [%{name: "Floor"}] = Dungeons.get_tiles(updated_level_2.id, 0, 2)
      [%{name: "Floor"}] = Dungeons.get_tiles(updated_level_2.id, 1, 1)
      [%{name: "Lamp"}] = Dungeons.get_tiles(updated_level_2.id, 1, 2)
    end
  end

  describe "create_spawn_locations/1" do
    test "it creates the spawn locations" do
      dungeon = insert_dungeon()
      level_1 = insert_stubbed_level(%{dungeon_id: dungeon.id, number: 1})
      level_2 = insert_stubbed_level(%{dungeon_id: dungeon.id, number: 2})

      export = %DungeonExports{
        dungeon: dungeon,
        levels: %{1 => level_1, 2 => level_2},
        spawn_locations: [[1, 0, 1], [1, 0, 3], [2, 1, 1]],
      }

      updated_export = create_spawn_locations(export)

      # does not actually modify the export
      assert updated_export == export

      # creates the spawn location records
      assert [{0, 1}, {0, 3}] = Repo.preload(level_1, :spawn_locations).spawn_locations
                                |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
                                |> Enum.sort()
      assert [{1, 1}] = Repo.preload(level_2, :spawn_locations).spawn_locations
                        |> Enum.map(fn(sl) -> {sl.row, sl.col} end)
    end
  end

  describe "complete_dungeon_import/1" do
    test "it sets import to false" do
      dungeon = insert_dungeon(%{importing: true})

      export = %DungeonExports{dungeon: dungeon}

      updated_export = complete_dungeon_import(export)

      refute updated_export.dungeon.importing
      refute Dungeons.get_dungeon(dungeon.id).importing
    end
  end
end
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

  describe "find_or_create_assets/3" do
    alias DungeonCrawl.Shipping

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

      user = insert_user()
      other_user = insert_user()
      dungeon_import = Shipping.create_import!(%{data: "{}", user_id: user.id, file_name: "x.json"})
      asset_from_import = Map.get(export, config.asset_key)[config.key]

      attrs = cond do
        config[:user_asset] -> %{user_id: user.id}
        config[:public_asset] -> %{user_id: nil, public: true}
        config[:others_existing_asset] -> %{user_id: other_user.id, slug: asset_from_import.slug, name: "Common field"}
        config[:existing_asset] -> %{user_id: user.id, slug: asset_from_import.slug, name: "Common field", script: "test"}
        config[:script_asset] -> %{user_id: user.id, script: "test words\n#sound tmp_sound1\n#become slug: tmp_ttid_1"}
        true -> %{}
      end
      attrs = Map.merge(asset_from_import, attrs)

      existing_asset_attrs = Map.merge(asset_from_import, attrs)
      asset = if config[:no_existing_asset],
                 do: nil,
                 else: config[:insert_asset_fn].(existing_asset_attrs)

      %{export: export, user: user, dungeon_import: dungeon_import, asset_from_import: asset_from_import, asset: asset, attrs: attrs, existing_attrs: existing_asset_attrs}
    end

    DungeonCrawl.SharedTests.finds_or_creates_assets_correctly(
      :items, "tmp_item_id_0", &insert_item/1, &Equipment.copy_fields/1)

    DungeonCrawl.SharedTests.finds_or_creates_assets_correctly(
      :tile_templates, "tmp_tt_id_0", &insert_tile_template/1, &TileTemplates.copy_fields/1)

    DungeonCrawl.SharedTests.finds_or_creates_assets_correctly(
      :sounds, "tmp_sound_id_0", &insert_effect/1, &Sound.copy_fields/1)
  end

  describe "find_asset/3 :sounds" do
    test "finds the effect, user id impacts nothing" do
      user_id = "not_used"
      click = SoundSeeder.click()

      attrs = Map.take(click, [:name, :public, :user_id, :zzfx_params, :slug])

      assert click == find_asset(:sounds, attrs, %{id: user_id})
      assert find_asset(:sounds, attrs, %{id: user_id}) == find_asset(:sounds, attrs, %{id: nil})
      refute find_asset(:sounds, %{ attrs | name: "different" <> click.name}, %{id: user_id})
    end
  end

  describe "find_asset/3 :items" do
    test "an existing public item can be used" do
      user = insert_user()
      potion = EquipmentSeeder.levitation_potion()

      attrs = Equipment.copy_fields(potion)
      assert potion == find_asset(:items, attrs, user)
    end

    test "an existing private item owned by someone else" do
      user = insert_user()
      user2 = insert_user(%{user_id_hash: "other"})
      item = insert_item(%{user_id: user2.id, public: false})

      attrs = Equipment.copy_fields(item)
      # right now, no checks happen to see if a slug belongs to someone else for a match
      assert item == find_asset(:items, attrs, user)
    end

    test "an existing item owned by importer" do
      user = insert_user()
      tile = insert_item(%{user_id: user.id})

      attrs = Equipment.copy_fields(tile)
      assert tile == find_asset(:items, attrs, user)
    end

    test "a nonexistant item" do
      user = insert_user()

      attrs = %{name: "non existant", script: "HI"}

      refute find_asset(:items, attrs, user)
    end

    test "an item with a script referencing a nonexistant asset slug" do
      user = insert_user()
      tile = insert_item(%{public: true, script: "#become slug: clay"})

      attrs = Equipment.copy_fields(tile)
      refute find_asset(:items, attrs, user)
    end

    test "with a slug, wraps the Equipment function" do
      user = insert_user()
      item = insert_item(%{user_id: user.id})
      other_item = insert_item(%{name: "other thing", public: false, user_id: user.id})
      assert find_asset(:items, item.slug, user) == item
      refute find_asset(:items, other_item.slug, %{ user | id: user.id + 1})
    end
  end

  describe "find_asset/3 :tile_templates" do
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
      assert bandit == find_asset(:tile_templates, attrs, user)

      # slightly different state causes a miss
      Ecto.Adapters.SQL.query!(DungeonCrawl.Repo,
        "UPDATE tile_templates SET state = '#{misorderd_state}, different: yes' WHERE id = #{bandit.id}", [])

      refute find_asset(:tile_templates, attrs, user)
    end

    test "an existing template that is private and someone elses" do
      user = insert_user()
      user2 = insert_user(%{user_id_hash: "other"})
      tile = insert_tile_template(%{user_id: user2.id, public: false})

      attrs = TileTemplates.copy_fields(tile)
      # right now, no checks happen to see if a slug belongs to someone else for a match
      assert tile == find_asset(:tile_templates, attrs, user)
    end

    test "an existing template owned by importer" do
      user = insert_user()
      tile = insert_tile_template(%{user_id: user.id})

      attrs = TileTemplates.copy_fields(tile)
      assert tile == find_asset(:tile_templates, attrs, user)
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

      refute find_asset(:tile_templates, attrs, user)
    end

    test "a template with a script refering to a slug that does not exist" do
      user = insert_user()
      tile = insert_tile_template(%{public: true, active: true, script: "#become slug: clay"})

      attrs = TileTemplates.copy_fields(tile)
      refute find_asset(:tile_templates, attrs, user)
    end

    test "with a slug wraps the TileTemplates function" do
      user = insert_user()
      admin = insert_user(%{is_admin: true})
      public_tile = insert_tile_template(%{active: false, public: true})
      private_tile = insert_tile_template(%{public: false, user_id: admin.id})
      owned_tile = insert_tile_template(%{active: false, public: false, user_id: user.id})

      assert find_asset(:tile_templates, public_tile.slug, nil)

      assert find_asset(:tile_templates, public_tile.slug, user)
      refute find_asset(:tile_templates, private_tile.slug, user)
      assert find_asset(:tile_templates, owned_tile.slug, user)

      assert find_asset(:tile_templates, public_tile.slug, admin)
      assert find_asset(:tile_templates, private_tile.slug, admin)
      assert find_asset(:tile_templates, owned_tile.slug, admin)
    end

    test "a template with nil state in the import and no state set on the record" do
      user = insert_user()
      tile = insert_tile_template(%{public: true, active: true, state: %{}})

      attrs = TileTemplates.copy_fields(tile)
              |> Map.put(:state, nil)
      assert find_asset(:tile_templates, attrs, user)
    end
  end

  describe "script_fuzzer/1" do
    test "replaces slugs with <FUZZ> for equivalent comparision purposes" <>
         "and normalizes line endings" do
      script = """
      #become character: X, slug: tmp_tt_id_1\r
      #become slug: tmp_tt_id_1, color: mauve\r
      #equip bacon, ?sender
      \r#unequip rocks, ?sender, label
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

  describe "create_asset/2 :sounds" do
    test "creates a sound effect" do
      attrs = %{name: "bloop", zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"}
      sound = create_asset(:sounds, attrs)
      assert sound.name == attrs.name
      assert sound.zzfx_params == attrs.zzfx_params
      assert is_integer(sound.id)
    end
  end

  describe "create_asset/2 :items" do
    test "creates an item" do
      attrs = %{name: "stick", script: "it does nothing"}
      item = create_asset(:items, attrs)
      assert item.name == attrs.name
      assert item.script == "#end"
      assert item.tmp_script == "it does nothing"
      assert is_integer(item.id)
    end
  end

  describe "create_asset/2 :tile_templates" do
    test "creates a tile template" do
      attrs = %{name: "stick", description: "it is a stick", script: "#end\n:touch\nyou pick it up"}
      tile_template = create_asset(:tile_templates, attrs)
      assert tile_template.name == attrs.name
      assert tile_template.script == "#end"
      assert tile_template.tmp_script == "#end\n:touch\nyou pick it up"
      assert is_integer(tile_template.id)
    end

    test "creates a tile template without a script" do
      attrs = %{name: "stick", description: "it is a stick"}
      tile_template = create_asset(:tile_templates, attrs)
      assert tile_template.name == attrs.name
      assert tile_template.script == ""
      refute tile_template.tmp_script
      assert is_integer(tile_template.id)
    end
  end

  describe "update_asset/3 :sounds" do
    test "updates the sound" do
      sound = insert_effect(%{name: "test", zzfx_params: "[,,,,,,,,,,,,,,,,,,]"})
      updated_zzfx = "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]"
      assert %{zzfx_params: ^updated_zzfx} =
               update_asset(:sounds, sound, %{zzfx_params: updated_zzfx})
    end

    test "invalid update" do
      sound = insert_effect(%{name: "test", zzfx_params: "[,,,,,,,,,,,,,,,,,,]"})
      updated_zzfx = ""
      assert_raise Ecto.InvalidChangesetError, fn ->
        update_asset(:sounds, sound, %{zzfx_params: updated_zzfx})
      end
    end
  end

  describe "update_asset/3 :items" do
    test "updates the item" do
      item = insert_item(%{script: "old script"})
      assert %{script: "#end", tmp_script: "new script"} =
               update_asset(:items, item, %{script: "new script"})
    end

    test "invalid update" do
      item = insert_item(%{script: "old script"})
      assert_raise Ecto.InvalidChangesetError, fn ->
        update_asset(:items, item, %{script: ""})
      end
    end
  end

  describe "update_asset/3 :tile_templates" do
    test "updates the tile template" do
      tile_template = insert_tile_template(%{script: "old script"})
      assert %{name: "new name", script: "#end", tmp_script: "new script"} =
               update_asset(:tile_templates, tile_template, %{name: "new name", script: "new script"})
    end

    test "invalid update" do
      tile_template = insert_tile_template(%{script: "old script"})
      assert_raise Ecto.InvalidChangesetError, fn ->
        update_asset(:tile_templates, tile_template, %{name: "", script: ""})
      end
    end
  end

  describe "create_and_add_slugs_to_built_assets/2" do
    setup do
      export = %DungeonExports{
        sounds: %{
          "tmp_sound_1" => %{zzfx_params: ""},
          "tmp_sound_2" => {:createable, %{zzfx_params: "[,0,130.8128,.1,.1,.34,3,1.88,,,,,,,,.1,,.5,.04]", name: "blorp"}, "blorp"}
        },
        items: %{
          "tmp_item_0" => {:createable, %{name: "test item", script: "#end"}, "test_item"},
          "tmp_item_1" => %{script: "does nothing"}
        },
        tile_templates: %{
          "tmp_ttid_0" => %{script: "#end\n:touch\nhey"},
          "tmp_ttid_1" => {:createable, %{name: "Test Rock", script: "#end", description: "its rock"}, "rock"}
        }
      }
       %{ export: export }
    end

    test "creates the assets marked as completely new", %{export: export} do
      assert 0 == Enum.count(Sound.list_effects())
      assert 0 == Enum.count(Equipment.list_items())
      assert 0 == Enum.count(TileTemplates.list_tile_templates())

      assert %{sounds: %{
        "tmp_sound_1" => sound_0,
        "tmp_sound_2" => sound_1
      }} = create_and_add_slugs_to_built_assets(export, :sounds)
      assert 1 == Enum.count(Sound.list_effects())
      assert sound_0 == export.sounds["tmp_sound_1"]
      assert sound_1 == Sound.get_effect!("blorp")

      assert %{ items: %{
        "tmp_item_0" => item_0,
        "tmp_item_1" => item_1
      }} = create_and_add_slugs_to_built_assets(export, :items)
      assert 1 == Enum.count(Equipment.list_items())
      assert Map.delete(item_0, :tmp_script) ==
               Map.delete(Equipment.get_item!("test_item"), :tmp_script)
      assert item_1 == export.items["tmp_item_1"]

      assert %{tile_templates: %{
        "tmp_ttid_0" => tt_0,
        "tmp_ttid_1" => tt_1
      }} = create_and_add_slugs_to_built_assets(export, :tile_templates)
      assert 1 == Enum.count(TileTemplates.list_tile_templates())
      assert tt_0 == export.tile_templates["tmp_ttid_0"]
      assert Map.delete(tt_1, :tmp_script) ==
               Map.delete(TileTemplates.get_tile_template("test_rock", nil), :tmp_script)
    end

    test "does not impact anything other than the specified assets", %{export: export} do
      assert Map.drop(export, [:sounds, :log]) ==
               Map.drop(create_and_add_slugs_to_built_assets(export, :sounds), [:sounds, :log])
      assert Map.drop(export, [:items, :log]) ==
               Map.drop(create_and_add_slugs_to_built_assets(export, :items), [:items, :log])
      assert Map.drop(export, [:tile_templates, :log]) ==
               Map.drop(create_and_add_slugs_to_built_assets(export, :tile_templates), [:tile_templates, :log])
    end

    test "noop when status is not running", export do
      export = Map.put export, :status, "halt"
      assert export == create_and_add_slugs_to_built_assets(export, :sounds)
      assert export == create_and_add_slugs_to_built_assets(export, :items)
      assert export == create_and_add_slugs_to_built_assets(export, :tile_templates)
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

    test "noop when status is not running", %{export: export} do
      export = %{ export | status: "halt" }

      assert export == repoint_ttids_and_slugs(export, :tiles)
      assert export == repoint_ttids_and_slugs(export, :items)
      assert export == repoint_ttids_and_slugs(export, :tile_templates)
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

    test "noop when status is not running" do
      export = %DungeonExports{
        tiles: %{"tile_hash" => %{script: "#end\n:touch\nhey"}},
        items: %{"tmp_item_0" => %{script: "does nothing"}},
        status: "halt"
      }

      assert export == swap_scripts_to_tmp_scripts(export, :tiles)
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

    test "noop when status is not running" do
      export = %DungeonExports{
        dungeon: %{state: %{"starting_equipment" => ["tmp_item_id_0", "tmp_item_id_0", "tmp_item_id_1"]}},
        items: %{"tmp_item_id_0" => %{slug: "thing"}, "tmp_item_id_1" => %{slug: "waffle"}},
        status: "halt"}

      assert export == repoint_dungeon_starting_items(export)
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

    test "noop when status is not running", %{export: export} do
      export = %{ export | status: "halt" }

      assert export == set_dungeon_overrides(export, 123, "9")
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

    test "noop when status is not running", %{dungeon: dungeon, user: user} do
      export = %DungeonExports{
        dungeon: %{line_identifier: dungeon.line_identifier, user_id: user.id},
        status: "halt"
      }

      assert export == maybe_handle_previous_version(export)
    end
  end

  describe "create_dungeon/1" do
    setup do
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

      %{export: export}
    end

    test "it creates the dungeon", %{export: export} do
      updated_export = create_dungeon(export)
      expected_dungeon =  Map.merge(%Dungeons.Dungeon{importing: true}, Dungeons.copy_dungeon_fields(export.dungeon))

      assert Map.drop(expected_dungeon, [:__meta__, :id, :inserted_at, :updated_at]) ==
               Map.drop(updated_export.dungeon, [:__meta__, :id, :inserted_at, :updated_at])

      assert is_integer(updated_export.dungeon.id)
    end

    test "noop when status is not running", %{export: export} do
      export = %{ export | status: "halt" }

      assert export == create_dungeon(export)
      assert [] == DungeonCrawl.Repo.all(Dungeons.Dungeon)
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

    test "noop when status is not running", %{export: export} do
      export = %{ export | status: "halt" }

      assert export == create_levels(export)
      assert [] == DungeonCrawl.Repo.all(Dungeons.Level)
    end
  end

  describe "create_spawn_locations/1" do
    setup do
      dungeon = insert_dungeon()
      level_1 = insert_stubbed_level(%{dungeon_id: dungeon.id, number: 1})
      level_2 = insert_stubbed_level(%{dungeon_id: dungeon.id, number: 2})

      export = %DungeonExports{
        dungeon: dungeon,
        levels: %{1 => level_1, 2 => level_2},
        spawn_locations: [[1, 0, 1], [1, 0, 3], [2, 1, 1]],
      }

      %{export: export, level_1: level_1, level_2: level_2}
    end

    test "it creates the spawn locations", %{export: export, level_1: level_1, level_2: level_2} do
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

    test "noop when the status is not running", %{export: export} do
      export = %{ export | status: "halt" }

      assert export == create_spawn_locations(export)
      assert [] == Repo.all(Dungeons.SpawnLocation)
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

    test "noop when status is not running" do
      export = %DungeonExports{dungeon: %{}, status: "halt"}

      assert export == complete_dungeon_import(export)
    end
  end

  describe "log/2" do
    test "it adds to the front of the log array" do
      assert %{log: ["and another thing", "test"]} =
               log(%DungeonExports{}, "test")
               |> log("and another thing")
    end
  end

  describe "log_time/2" do
    test "it adds to the front of the log array" do
      assert %{log: [last_log, "test"]} =
               log_time(%DungeonExports{log: ["test"]}, "Start: ")
      assert last_log =~ ~r/Start: \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC/
    end
  end
end
defmodule DungeonCrawl.Shipping.Private.ImportFunctionsTest do
  use DungeonCrawl.DataCase

  import DungeonCrawl.Shipping.Private.ImportFunctions

  alias DungeonCrawl.TileTemplates.TileSeeder, as: TileTemplateSeeder
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder

  alias DungeonCrawl.Equipment
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.Sound
  alias DungeonCrawl.StateValue.Parser

  alias DungeonCrawlWeb.ExportFixture

  require DungeonCrawl.SharedTests

  # TODO: for each of these functions make sure to assert and check the significant changes to export;
  # some will change a whole node after looking up a record but that may not be significant
  # as some functions, such as repoint, only care about the ID and new slug that was added
  # when they change data related to their operation (such as changing a temporary tile template id
  # from "tmp_..." to the record ID from the backing database.

  describe "find_or_create_assets/5" do
    setup config do
      existing_asset = Map.get(ExportFixture.minimal_export(), config.asset_key)[config.key]

      export = %DungeonCrawl.Shipping.DungeonExports{}
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

      expected = %{
        click_slug: "click",
        rock_tt_id: 100,
        rock_tt_slug: "rock",
        stone_tt_slug: "stone",
        stone_item_slug: "stone_456",
        thing_script: ""
      }

      export_mock =
      %{
        tile_templates: %{
          "tmp_tt_id_0" => %{
            id: expected.rock_tt_id,
            slug: expected.rock_tt_slug
          },
          "tmp_tt_id_1" => %{
            id: 101,
            slug: expected.stone_tt_slug,
            script: "#end",
            tmp_script: "#end\n:touch\n#equip tmp_item_id_1, ?sender\n#die"
          },
        },
        sounds: %{
          "tmp_sound_id_0" => %{id: 900, slug: expected.click_slug},
          "tmp_sound_id_1" => %{id: 998, slug: "blip"},
          "tmp_sound_id_2" => %{id: 999, slug: "shoot"}
        },
        items: %{
          "tmp_item_id_1" => %{
            id: 456,
            # slugs can be the same for different assets, this is mainly to verify stone item slug
            # is used rather than the stone tile template id for purposes of the tests
            slug: expected.stone_item_slug,
            script: "#end",
            tmp_script: "#put direction: here, slug: tmp_tt_id_1, facing: @facing, thrown: true\n"
          }
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

      %{
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

      %{
        items: %{
          "tmp_item_id_1" => stone_item
        }
      } = updated_export

      assert stone_item.script ==
               "#put direction: here, slug: #{ expected.stone_tt_slug }, facing: @facing, thrown: true\n"
    end

    test "repoints tile_templates", %{export: export, expected: expected} do
      updated_export = repoint_ttids_and_slugs(export, :tile_templates)

      # only changes the given asset
      assert Map.drop(updated_export, [:tile_templates]) == Map.drop(export, [:tile_templates])

      %{
        tile_templates: %{
          "tmp_tt_id_0" => rock_tt,
          "tmp_tt_id_1" => stone_tt
        }
      } = updated_export

      # nothing changed for rock tile template
      assert rock_tt == export.tile_templates["tmp_tt_id_0"]
      # update stone script
      assert stone_tt.script == "#end\n:touch\n#equip #{ expected.stone_item_slug }, ?sender\n#die"
    end
  end

  describe "repoint_tile_template_id/2" do
    test "repoints the tile_template_id" do
      export = %{tile_templates: %{"tmp_tt_id_0" => %{id: 500}}}
      asset = %{tile_template_id: "tmp_tt_id_0"}
      updated_asset = repoint_tile_template_id(asset, export)
      assert updated_asset.tile_template_id == 500
    end

    test "does nothing if the asset does not have a tile_template_id" do
      export = %{tile_templates: %{"tmp_tt_id_0" => %{id: 500}}}
      asset = %{tile_template_id: nil}
      updated_asset = repoint_tile_template_id(asset, export)
      refute updated_asset.tile_template_id
    end
  end

  describe "repoint_dungeon_starting_items/1" do
  end

  describe "set_dungeon_overrides/3" do
  end

  describe "maybe_handle_previous_version/1" do
  end

  describe "create_dungeon/1" do
  end

  describe "create_levels/1" do
  end

  describe "create_levels/2" do
  end

  describe "create_tiles/3" do
  end

  describe "create_spawn_locations/1" do
  end

  describe "complete_dungeon_import/1" do
  end
end
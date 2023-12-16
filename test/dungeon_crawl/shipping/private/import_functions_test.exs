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
      user_id = insert_user().id

      # sort of cheating with the setup; as this test assumes the functions below return correct results
      # but also guarantees that `export` will have the proper changes that this function will use.
      export = ExportFixture.minimal_export()
               |> find_or_create_assets(:sounds, &find_effect/2, &Sound.create_effect!/1, user_id)
               |> find_or_create_assets(:items, &find_item/2, &Equipment.create_item!/1, user_id)
               |> find_or_create_assets(:tile_templates, &find_tile_template/2, &TileTemplates.create_tile_template!/1, user_id)
               |> swap_scripts_to_tmp_scripts(:tiles)

      # todo: delete this inspect and unused map; its here for now to remind how this map looks and what \
      # the important bits look like for this test scetion
      IO.inspect export
      %{
        tile_templates: %{
          "tmp_tt_id_0" => %{
            id: rock_tt_id,
            slug: rock_tile_slug
          },
          "tmp_tt_id_1" => %{
            id: stone_tt_id,
            slug: stone_tile_slug
          },
        },
        sounds: %{
          "tmp_sound_id_0" => %{id: click_id, slug: click_slug},
          "tmp_sound_id_1" => %{id: blip_id, slug: blip_slug},
          "tmp_sound_id_2" => %{id: shoot_id, slug: shoot_slug}
        },
        items: %{
          "tmp_item_id_0" => %{},
          "tmp_item_id_1" => %{slug: stone_slug}
        }
      } = export

     %{ export: export }
    end

    test "repoints tiles", %{export: export} do
      updated_export = repoint_ttids_and_slugs(export, :tiles)

      rock_tt_id =       export.tile_templates["tmp_tt_id_0"].id
      rock_tt_slug =     export.tile_templates["tmp_tt_id_0"].slug
      click_sound_slug = export.sounds["tmp_sound_id_0"].slug
      stone_item_slug =  export.items["tmp_item_id_1"].slug

      thing_script = updated_export.tiles["thing_hash"].script
      thing_tmp_script = updated_export.tiles["thing_hash"].tmp_script
      click_slug = updated_export.sounds["tmp_sound_id_0"].slug
      stone_slug = updated_export.items["tmp_item_id_1"].slug
      rock_tile_slug = updated_export.tile_templates["tmp_tt_id_0"].slug
      assert rock_tt_id == updated_export.tiles["rock_hash"].tile_template_id
      refute updated_export.tiles["thing_hash"].tile_template_id
      assert thing_script == updated_export.tiles["thing_hash"].tmp_script


      assert rock_tt_id == TileTemplates.get_tile_template_by_slug(rock_tile_slug).id
      assert thing_script == thing_tmp_script
      assert thing_script ==
               "#end\n:touch\n#sound #{ click_slug }\n#equip #{ stone_slug }, ?sender\n#become slug: #{ rock_tile_slug }"
    end

    test "repoints items" do

    end
    test "repoints tile_templates" do

    end
  end

  describe "repoint_tile_template_id/2" do
  end

  describe "repoint_script_slugs/4" do
  end

  describe "swap_scripts_to_tmp_scripts/2" do
  end

  describe "swap_tmp_script/1" do
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
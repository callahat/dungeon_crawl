defmodule DungeonCrawl.Shipping.Private.ImportFunctionsTest do
  use DungeonCrawl.DataCase

  import DungeonCrawl.Shipping.Private.ImportFunctions

  alias DungeonCrawl.TileTemplates.TileSeeder, as: TileTemplateSeeder
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder

  alias DungeonCrawl.Equipment
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.StateValue.Parser

  # invocations from DungeonImports
  # find_or_create_assets(export, :sounds, &find_effect/2, &Sound.create_effect!/1, user_id)
  # find_or_create_assets(:items, &find_item/2, &Equipment.create_item!/1, user_id)
  # find_or_create_assets(:tile_templates, &find_tile_template/2, &TileTemplates.create_tile_template!/1, user_id)
  describe "find_or_create_assets/5" do

  end

  describe "find_effect/2" do
    test "finds the effect, user id impacts nothing" do
      user_id = "not_used"
      click = SoundSeeder.click

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
      bandit = TileTemplateSeeder.bandit
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

  # this one might be better to just make internal, because its only used for tile template
  # and item after its already been looked up, and this function uses script fuzzer and all
  # slugs usable
  describe "useable_asset/3" do
    # this check is not performed for Sound
    test "a template that should be useable" do

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

    end

    test "a sound slug is not usable" do

    end

    test "an item slug is not usable" do

    end

    test "a tile template slug is not usable" do

    end

    test "some slugs are usable, some are not" do

    end
  end

  describe "repoint_ttids_and_slugs/2" do
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
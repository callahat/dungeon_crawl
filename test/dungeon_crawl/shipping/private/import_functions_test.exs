defmodule DungeonCrawl.Shipping.Private.ImportFunctionsTest do
  use DungeonCrawl.DataCase

  import DungeonCrawl.Shipping.Private.ImportFunctions

  alias DungeonCrawl.TileTemplate.Seeder, as: TileTemplateSeeder
  alias DungeonCrawl.Equipment.Seeder, as: EquipmentSeeder
  alias DungeonCrawl.Sound.Seeder, as: SoundSeeder

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
  end

  describe "find_tile_template/2" do
    test "an existing public template can be used" do

    end

    test "an existing template that is private and someone elses"
    end

    test "an existing template owned by importer" do

    end

    test "a template that does not exist" do

    end
  end

  describe "useable_asset/3" do
    # this check is not performed for Sound
    test "a template that should be useable" do
      bandit TileTemplateSeeder.bandit

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
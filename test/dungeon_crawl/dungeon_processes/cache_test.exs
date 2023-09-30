defmodule DungeonCrawl.DungeonProcesses.CacheTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonProcesses.Cache
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Equipment.Seeder.Item
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Sound
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileSeeder.BasicTiles

  test "get_state/1" do
    {:ok, cache_process} = Cache.start_link([])

    assert %Cache{} == Cache.get_state(cache_process)
  end

  test "clear/1" do
    {:ok, cache_process} = Cache.start_link([])

    assert :ok == Cache.clear(cache_process)
    assert %Cache{} == Cache.get_state(cache_process)
  end

  test "get_tile_template/3" do
    {:ok, cache_process} = Cache.start_link([])
    author = insert_user()

    assert {nil, :not_found} = Cache.get_tile_template(cache_process, "fake_slug", author)

    BasicTiles.bullet_tile

    # looks up from the database and caches it
    assert {bullet, :created} = Cache.get_tile_template(cache_process, "bullet", author)
    assert bullet.name == "Bullet"
    state = Cache.get_state(cache_process)
    assert state.tile_templates["bullet"] == bullet

    # finds it in the cache and returns it
    assert {bullet, :exists} == Cache.get_tile_template(cache_process, "bullet", author)
    assert state == Cache.get_state(cache_process)

    # an id is given instead / template not found
    assert {nil, :not_found} = Cache.get_tile_template(cache_process, bullet.id, author)
    assert state == Cache.get_state(cache_process)

    # template cannot be since dungeon has author whom is not an admin nor owner of the non public slug
    Cache.clear(cache_process)
    TileTemplates.update_tile_template(bullet, %{user_id: insert_user().id})
    assert {nil, :not_found} = Cache.get_tile_template(cache_process, "bullet", author)
    assert %Cache{} == Cache.get_state(cache_process)
  end

  test "get_item/3" do
    {:ok, cache_process} = Cache.start_link([])
    author = insert_user()

    assert {nil, :not_found} = Cache.get_item(cache_process, "fake_slug", author)

    Item.gun

    # looks up from the database and caches it
    assert {item, :created} = Cache.get_item(cache_process, "gun", author)
    assert item.name == "Gun"
    state = Cache.get_state(cache_process)
    assert state.items["gun"] == item

    assert %{program: %Program{instructions: instructions}} = state.items["gun"]
    assert %{1 => [:take, ["ammo", 1, [:self], "error"]],
             2 => [:shoot, [state_variable: "facing"]],
             3 => [:sound, ["shoot"]],
             4 => [:halt, [""]],
             5 => [:noop, "error"],
             6 => [:text, [["Out of ammo!"]]],
             7 => [:sound, ["click"]]} == instructions

    # finds it in the cache and returns it
    assert {item, :exists} == Cache.get_item(cache_process, "gun", author)
    assert state == Cache.get_state(cache_process)

    # an id is given instead / template not found
    assert {nil, :not_found} = Cache.get_item(cache_process, item.id, author)
    assert state == Cache.get_state(cache_process)

    # item cannot be used since dungeon has author whom is not an admin nor owner of the non public slug
    Cache.clear(cache_process)
    Equipment.update_item(item, %{user_id: insert_user().id, public: false})
    assert {nil, :not_found} = Cache.get_item(cache_process, "gun", author)
    assert %Cache{} == Cache.get_state(cache_process)
  end

  test "get_sound_effect/3" do
    {:ok, cache_process} = Cache.start_link([])
    author = insert_user()

    assert {nil, :not_found} = Cache.get_sound_effect(cache_process, "fake_slug", author)

    insert_effect()

    # looks up from the database and caches it
    assert {beep, :created} = Cache.get_sound_effect(cache_process, "beep", author)
    assert beep.name == "Beep"
    state = Cache.get_state(cache_process)
    assert state.sound_effects["beep"] == beep

    # finds it in the cache and returns it
    assert {beep, :exists} == Cache.get_sound_effect(cache_process, "beep", author)
    assert state == Cache.get_state(cache_process)

    # an id is given instead / template not found
    assert {nil, :not_found} = Cache.get_sound_effect(cache_process, beep.id, author)
    assert state == Cache.get_state(cache_process)

    # template cannot be since dungeon has author whom is not an admin nor owner of the non public slug
    Cache.clear(cache_process)
    Sound.update_effect(beep, %{user_id: insert_user().id})
    assert {nil, :not_found} = Cache.get_sound_effect(cache_process, "beep", author)
    assert %Cache{} == Cache.get_state(cache_process)
  end
end


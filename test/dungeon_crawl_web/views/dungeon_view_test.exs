defmodule DungeonCrawlWeb.DungeonViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.DungeonView

  test "activate_or_new_version_button/2 renders activate if dungeon inactive", %{conn: conn} do
    map = insert_autogenerated_dungeon(%{active: false})
    assert Regex.match?(~r{Activate}, inspect(DungeonView.activate_or_new_version_button(conn, map, nil)))
    assert Regex.match?(~r{Test Crawl}, inspect(DungeonView.activate_or_new_version_button(conn, map, nil)))
    refute Regex.match?(~r{Your current crawl will be lost}, inspect(DungeonView.activate_or_new_version_button(conn, map, nil)))

    instance = insert_stubbed_dungeon_instance(%{active: true})
    location = insert_player_location(%{map_instance_id: instance.id, user_id_hash: "testhash"})
    assert Regex.match?(~r{Test Crawl}, inspect(DungeonView.activate_or_new_version_button(conn, map, location)))
    assert Regex.match?(~r{Your current crawl will be lost}, inspect(DungeonView.activate_or_new_version_button(conn, map, location)))
  end

  test "activate_or_new_version_button/2 renders nothing if a new version already exists", %{conn: conn} do
    map = insert_autogenerated_dungeon()
    _new_version = insert_autogenerated_dungeon(%{previous_version_id: map.id})
    refute DungeonView.activate_or_new_version_button(conn, map, nil)
  end

  test "activate_or_new_version_button/2 renders new_version if dungeon active", %{conn: conn} do
    map = insert_autogenerated_dungeon()
    assert Regex.match?(~r{New Version}, inspect(DungeonView.activate_or_new_version_button(conn, map, nil)))
  end

  test "tile_template_pres/1 returns safely the pre tiles for the given tile templates" do
    tt1 = insert_tile_template(%{character: "1"})
    tt2 = insert_tile_template(%{character: "2"})
    assert {:safe, pres} = DungeonView.tile_template_pres([tt1,tt2])
    assert pres =~ ~r|<pre.*?><span>1</span></pre>|s
    assert pres =~ ~r|<pre.*?><span>2</span></pre>|s
  end

  test "tile_template_pres/2 returns safely the pre tiles for the given tile templates with the historic flag" do
    tt1 = insert_tile_template(%{character: "1"})
    tt2 = insert_tile_template(%{character: "2"})
    assert {:safe, pres} = DungeonView.tile_template_pres([tt1,tt2], true)
    assert pres =~ ~r|<pre.*?data-historic-template=true.*?><span>1</span></pre>|s
    assert pres =~ ~r|<pre.*?data-historic-template=true.*?><span>2</span></pre>|s
  end

  test "color_tr/1 returns safely a table row where the cells are the colors given" do
    assert {:safe, tr}  = DungeonView.color_tr(["red","white","blue"])
    assert tr =~ ~r|<td data-color="red".*?</td>|
    assert tr =~ ~r|<td data-color="white".*?</td>|
    assert tr =~ ~r|<td data-color="blue".*?</td>|
  end
end

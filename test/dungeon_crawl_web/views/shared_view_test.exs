defmodule DungeonCrawlWeb.SharedViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  import DungeonCrawlWeb.SharedView
  alias DungeonCrawl.Dungeon.MapTile

  test "tile_and_style/1 with nil" do
    assert tile_and_style(nil) == ""
  end

  test "tile_and_style/2 with nil" do
    assert tile_and_style(nil, :safe) == {:safe, ""}
  end

  test "tile_and_style/2 using :safe returns a tuple marked html safe" do
    stub_map_tile = %MapTile{character: "!"}
    assert tile_and_style(stub_map_tile, :safe) == {:safe, "<span>!</span>"}
  end

  test "tile_and_style/1 returns the html" do
    stub_map_tile = %MapTile{character: "!"}
    assert tile_and_style(stub_map_tile) == "<span>!</span>"
  end

  test "tile_and_style returns html for different stylings" do
    a = %MapTile{character: "A"}
    b = %MapTile{character: "B", color: "red"}
    c = %MapTile{character: "C", background_color: "black"}
    d = %MapTile{character: "D", color: "#FFF", background_color: "#000"}

    style_a = tile_and_style(a)
    style_b = tile_and_style(b)
    style_c = tile_and_style(c)
    style_d = tile_and_style(d)

    assert {:safe, style_a} == tile_and_style(a, :safe)
    assert {:safe, style_b} == tile_and_style(b, :safe)
    assert {:safe, style_c} == tile_and_style(c, :safe)
    assert {:safe, style_d} == tile_and_style(d, :safe)

    assert style_a == "<span>A</span>"
    assert style_b == "<span style='color: red'>B</span>"
    assert style_c == "<span style='background-color: black'>C</span>"
    assert style_d == "<span style='color: #FFF;background-color: #000'>D</span>"
  end

  test "dungeon_as_table/1 returns table rows of the dungeon" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})
    map = insert_stubbed_dungeon(%{},
            [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color])),
             Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color])),
             Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, [:character, :color, :background_color]))])

    rows = dungeon_as_table(Repo.preload(map, :dungeon_map_tiles))

    assert rows =~ ~r{<td id='1_1'><span>A</span></td>}
    assert rows =~ ~r{<td id='1_2'><span>A</span></td>}
    assert rows =~ ~r{<td id='1_3'><span style='color: #FFF'>B</span></td>}
  end

  test "dungeon_as_table/2 returns table rows of the dungeon including the tile_template_id" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})
    map = insert_stubbed_dungeon(%{},
            [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color])),
             Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color])),
             Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, [:character, :color, :background_color]))])

    rows = dungeon_as_table(Repo.preload(map, :dungeon_map_tiles), true)

    assert rows =~ ~r|<td id='1_1' data-tile-template-id='#{tile_a.id}'><span>A</span></td>|
    assert rows =~ ~r|<td id='1_2' data-tile-template-id='#{tile_a.id}'><span>A</span></td>|
    assert rows =~ ~r|<td id='1_3' data-tile-template-id='#{tile_b.id}'><span style='color: #FFF'>B</span></td>|
  end
end

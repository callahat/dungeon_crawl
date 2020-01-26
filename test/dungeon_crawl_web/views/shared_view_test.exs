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
    assert tile_and_style(stub_map_tile, :safe) == {:safe, "<div>!</div>"}
  end

  test "tile_and_style/1 returns the html" do
    stub_map_tile = %MapTile{character: "!"}
    assert tile_and_style(stub_map_tile) == "<div>!</div>"
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

    assert style_a == "<div>A</div>"
    assert style_b == "<div style='color: red'>B</div>"
    assert style_c == "<div style='background-color: black'>C</div>"
    assert style_d == "<div style='color: #FFF;background-color: #000'>D</div>"
  end

  test "dungeon_as_table/3 returns table rows of the dungeon" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})
    map = insert_stubbed_dungeon(%{},
            [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
             Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
             Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])

    rows = dungeon_as_table(Repo.preload(map, :dungeon_map_tiles), map.width, map.height)

    assert rows =~ ~r{<td id='1_1'><div>A</div></td>}
    assert rows =~ ~r{<td id='1_2'><div>A</div></td>}
    assert rows =~ ~r{<td id='1_3'><div style='color: #FFF'>B</div></td>}
  end

  test "editor_dungeon_as_table/3 returns table rows of the dungeon including the data attributes" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})
    map = insert_stubbed_dungeon(%{},
            [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
             Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, [:character, :color, :background_color, :state, :script])),
             Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, [:character, :color, :background_color, :state, :script]))])

    rows = editor_dungeon_as_table(Repo.preload(map, :dungeon_map_tiles), map.width, map.height)

    assert rows =~ ~r|<td id='1_1'><div data-z-index=0 data-color='' data-background-color='' data-tile-template-id='#{tile_a.id}'><div>A</div></div></td>|
    assert rows =~ ~r|<td id='1_2'><div data-z-index=0 data-color='' data-background-color='' data-tile-template-id='#{tile_a.id}'><div>A</div></div></td>|
    assert rows =~ ~r|<td id='1_3'><div data-z-index=0 data-color='#FFF' data-background-color='' data-tile-template-id='#{tile_b.id}'><div style='color: #FFF'>B</div></div></td>|
  end
end

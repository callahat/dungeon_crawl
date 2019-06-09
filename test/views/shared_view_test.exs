defmodule DungeonCrawlWeb.SharedViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  import DungeonCrawlWeb.SharedView

  test "tile_and_style/2 using :safe returns a tuple marked html safe" do
    tile_template = insert_tile_template %{character: "!"}
    assert tile_and_style(tile_template, :safe) == {:safe, "<span>!</span>"}
  end

  test "tile_and_style/1 returns the html" do
    tile_template = insert_tile_template %{character: "!"}
    assert tile_and_style(tile_template) == "<span>!</span>"
  end

  test "tile_and_style returns html for different stylings" do
    a = insert_tile_template %{character: "A"}
    b = insert_tile_template %{character: "B", color: "red"}
    c = insert_tile_template %{character: "C", background_color: "black"}
    d = insert_tile_template %{character: "D", color: "#FFF", background_color: "#000"}

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
end

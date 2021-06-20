defmodule DungeonCrawlWeb.LevelViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.LevelView

  test "tile_template_pres/1 returns safely the pre tiles for the given tile templates" do
    tt1 = insert_tile_template(%{character: "1"})
    tt2 = insert_tile_template(%{character: "2"})
    assert {:safe, pres} = LevelView.tile_template_pres([tt1,tt2])
    assert pres =~ ~r|<pre.*?><div>1</div></pre>|s
    assert pres =~ ~r|<pre.*?><div>2</div></pre>|s
  end

  test "tile_template_pres/2 returns safely the pre tiles for the given tile templates with the historic flag" do
    tt1 = insert_tile_template(%{character: "1"})
    tt2 = insert_tile_template(%{character: "2"})
    assert {:safe, pres} = LevelView.tile_template_pres([tt1,tt2], true)
    assert pres =~ ~r|<pre.*?data-historic-template=true.*?><div>1</div></pre>|s
    assert pres =~ ~r|<pre.*?data-historic-template=true.*?><div>2</div></pre>|s
  end

  test "color_tr/1 returns safely a table row where the cells are the colors given" do
    assert {:safe, tr}  = LevelView.color_tr(["red","white","blue"])
    assert tr =~ ~r|<td data-color="red".*?</td>|
    assert tr =~ ~r|<td data-color="white".*?</td>|
    assert tr =~ ~r|<td data-color="blue".*?</td>|
  end

  test "render/2 returns json for changeset errors" do
    no_errors = []
    errors = [
      character: {"should be at most %{count} character(s)", [count: 1, validation: :length, kind: :max, type: :string]}
    ]

    assert %{errors: [], tile: %{character: "a"}} = LevelView.render("tile_errors.json", %{tile_errors: no_errors, tile: %{character: "a"}})
    assert %{errors: [
                %{detail: "should be at most 1 character(s)", field: :character}
              ],
             tile: %{character: "boo"}
           } = LevelView.render("tile_errors.json", %{tile_errors: errors, tile: %{character: "boo"}})
    assert %{errors: [ %{detail: "it bad", field: :script} ], tile: _ } =
           LevelView.render("tile_errors.json", %{tile_errors: [script: "it bad"], tile: %{}})
  end
end

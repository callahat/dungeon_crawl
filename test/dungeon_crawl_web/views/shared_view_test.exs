defmodule DungeonCrawlWeb.SharedViewTest do
  use DungeonCrawlWeb.ConnCase#, async: true

  import DungeonCrawlWeb.SharedView
  alias DungeonCrawlWeb.SharedView
  alias DungeonCrawl.Dungeons.Tile
  alias DungeonCrawl.DungeonProcesses.LevelProcess

  @copyable_attrs [:character, :color, :background_color, :state, :script]

  test "tile_and_style/1 with nil" do
    assert tile_and_style(nil) == "<div> </div>"
  end

  test "tile_and_style/2 with nil" do
    assert tile_and_style(nil, :safe) == {:safe, "<div> </div>"}
  end

  test "tile_and_style/2 using :safe returns a tuple marked html safe" do
    stub_tile = %Tile{character: "!"}
    assert tile_and_style(stub_tile, :safe) == {:safe, "<div>!</div>"}
  end

  test "tile_and_style/1 returns the html" do
    stub_tile = %Tile{character: "!"}
    assert tile_and_style(stub_tile) == "<div>!</div>"
  end

  test "tile_and_style returns html for different stylings" do
    a = %Tile{character: "A"}
    b = %Tile{character: "B", color: "red"}
    c = %Tile{character: "C", background_color: "black"}
    d = %Tile{character: "D", color: "#FFF", background_color: "#000"}

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

  test "level_as_table/3 returns table rows of the level" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})
    level = insert_stubbed_level(%{},
              [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 1, z_index: 1}, Map.take(tile_b, @copyable_attrs))])

    rows = level_as_table(Repo.preload(level, :tiles), level.width, level.height)

    assert rows =~ ~r{<td id='1_1'><div style='color: #FFF'>B</div></td>}
    assert rows =~ ~r{<td id='1_2'><div>A</div></td>}
    assert rows =~ ~r{<td id='1_3'><div style='color: #FFF'>B</div></td>}
  end

  test "level_as_table/3 returns table rows of the level instance" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})

    {:ok, instance_process} = LevelProcess.start_link([])

    instance = insert_stubbed_level_instance(%{},
                 [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
                  Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
                  Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, @copyable_attrs)),
                  Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 1, z_index: 1}, Map.take(tile_b, @copyable_attrs))])

    LevelProcess.set_instance_id(instance_process, instance.id)
    LevelProcess.load_level(instance_process, Repo.preload(instance, :tiles).tiles)

    rows = level_as_table(instance, instance.width, instance.height)

    assert rows =~ ~r{<td id='1_1'><div style='color: #FFF'>B</div></td>}
    assert rows =~ ~r{<td id='1_2'><div>A</div></td>}
    assert rows =~ ~r{<td id='1_3'><div style='color: #FFF'>B</div></td>}

    # Also can be given the instance state object as well if thats available
    instance_state = LevelProcess.get_state(instance_process)
    rows = level_as_table(instance_state, instance.width, instance.height)

    assert rows =~ ~r{<td id='1_1'><div style='color: #FFF'>B</div></td>}
    assert rows =~ ~r{<td id='1_2'><div>A</div></td>}
    assert rows =~ ~r{<td id='1_3'><div style='color: #FFF'>B</div></td>}

    # cleanup
    Process.exit(instance_process, :kill)
  end

  test "level_as_table/3 returns table rows of the level instance when its foggy" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})

    {:ok, instance_process} = LevelProcess.start_link([])

    instance = insert_stubbed_level_instance(%{state: "visibility: fog"},
                 [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
                  Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
                  Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, @copyable_attrs)),
                  Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 1, z_index: 1}, Map.take(tile_b, @copyable_attrs))])
    LevelProcess.set_state_values(instance_process, %{visibility: "fog"})
    LevelProcess.set_instance_id(instance_process, instance.id)
    LevelProcess.load_level(instance_process, Repo.preload(instance, :tiles).tiles)

    # The DB record won't have parsed state_values, so it will appear normal/not foggy.
    rows = level_as_table(instance, instance.width, instance.height)

    assert rows =~ ~r{<td id='1_1'><div style='color: #FFF'>B</div></td>}
    assert rows =~ ~r{<td id='1_2'><div>A</div></td>}
    assert rows =~ ~r{<td id='1_3'><div style='color: #FFF'>B</div></td>}

    # Also can be given the instance state object as well if thats available
    instance_state = LevelProcess.get_state(instance_process)

    rows = level_as_table(instance_state, instance.width, instance.height)

    assert rows =~ ~r{<td id='1_1'><div style='background-color: darkgray'>░</div></td>}
    assert rows =~ ~r{<td id='1_2'><div style='background-color: darkgray'>░</div></td>}
    assert rows =~ ~r{<td id='1_3'><div style='background-color: darkgray'>░</div></td>}

    # cleanup
    Process.exit(instance_process, :kill)
  end

  test "editor_level_as_table/3 returns table rows of the level including the data attributes" do
    tile_a = insert_tile_template(%{character: "A"})
    tile_b = insert_tile_template(%{character: "B", color: "#FFF"})
    level = insert_stubbed_level(%{},
              [Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 1, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_a.id, row: 1, col: 2, z_index: 0}, Map.take(tile_a, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 3, z_index: 0}, Map.take(tile_b, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 1, z_index: 1}, Map.take(tile_b, @copyable_attrs)),
               Map.merge(%{tile_template_id: tile_b.id, row: 1, col: 4, z_index: 1, animate_colors: "red,blue", animate_characters: "1,2,3"},
                         Map.take(tile_b, @copyable_attrs))])

    rows = editor_level_as_table(Repo.preload(level, :tiles), level.width, level.height)

    tile_a_0 = "<div data-z-index=0 data-color='' data-background-color='' data-tile-template-id='#{tile_a.id}' data-character='A' data-state='blocking: false' data-script='' data-name='' data-random='' data-period='' data-characters='' data-colors='' data-background-colors=''><div>A</div></div>"
    tile_b_0 = "<div data-z-index=0 data-color='#FFF' data-background-color='' data-tile-template-id='#{tile_b.id}' data-character='B' data-state='blocking: false' data-script='' data-name='' data-random='' data-period='' data-characters='' data-colors='' data-background-colors=''><div style='color: #FFF'>B</div></div>"
    tile_a_0_hidden = "<div class='hidden' data-z-index=0 data-color='' data-background-color='' data-tile-template-id='#{tile_a.id}' data-character='A' data-state='blocking: false' data-script='' data-name='' data-random='' data-period='' data-characters='' data-colors='' data-background-colors=''><div>A</div></div>"
    tile_b_1 = "<div data-z-index=1 data-color='#FFF' data-background-color='' data-tile-template-id='#{tile_b.id}' data-character='B' data-state='blocking: false' data-script='' data-name='' data-random='' data-period='' data-characters='' data-colors='' data-background-colors=''><div style='color: #FFF'>B</div></div>"
    tile_b_4 = "<div data-z-index=1 data-color='#FFF' data-background-color='' data-tile-template-id='#{tile_b.id}' data-character='B' data-state='blocking: false' data-script='' data-name='' data-random='' data-period='' data-characters='1,2,3' data-colors='red,blue' data-background-colors=''><div class=' animate' data-random='' data-period='' data-characters='1,2,3' data-colors='red,blue' data-background-colors='' style='color: #FFF'>B</div></div>"

    [td_1_1] = Regex.run(~r|<td id='1_1'>.*?</td>|, rows)
    [td_1_2] = Regex.run(~r|<td id='1_2'>.*?</td>|, rows)
    [td_1_3] = Regex.run(~r|<td id='1_3'>.*?</td>|, rows)
    [td_1_4] = Regex.run(~r|<td id='1_4'>.*?</td>|, rows)

    assert td_1_1 == "<td id='1_1'>#{tile_b_1}#{tile_a_0_hidden}</td>"
    assert td_1_2 == "<td id='1_2'>#{tile_a_0}</td>"
    assert td_1_3 == "<td id='1_3'>#{tile_b_0}</td>"
    assert td_1_3 == "<td id='1_3'>#{tile_b_0}</td>"
    assert td_1_4 == "<td id='1_4'>#{tile_b_4}</td>"
    assert rows =~ ~r|<td class='edge'|
    assert rows =~ ~r|<td id='west_|
  end

  test "character_quick_list_html" do
    assert is_binary(character_quick_list_html())
  end

  test "state_fields.html" do
    {:safe, rendered_fields} =
      Phoenix.View.render(SharedView, "state_fields.html", state: "foo: bar, baz: qux", form: %{name: "tile_template"})
    rendered_fields = Enum.join(rendered_fields, "")
    assert rendered_fields =~ ~r|<input class="form-control" name="tile_template\[state_variables\]\[\]" type="text" value="foo">|
    assert rendered_fields =~ ~r|<input class="form-control" name="tile_template\[state_values\]\[\]" type="text" value="bar">|
    assert rendered_fields =~ ~r|<button type="button" class="btn btn-danger delete-state-fields-row">X</button>|
    assert rendered_fields =~ ~r|<input class="form-control" name="tile_template\[state_variables\]\[\]" type="text" value="baz">|
    assert rendered_fields =~ ~r|<input class="form-control" name="tile_template\[state_values\]\[\]" type="text" value="qux">|
    assert rendered_fields =~ ~r|<button type="button" class="btn btn-danger delete-state-fields-row">X</button>|
  end
end

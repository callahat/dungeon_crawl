defmodule DungeonCrawlWeb.Editor.DungeonViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.Editor.DungeonView

  test "activate_or_new_version_button/2 renders activate if dungeon inactive", %{conn: conn} do
    dungeon = insert_stubbed_dungeon(%{active: false})
    assert Regex.match?(~r{Activate}, inspect(DungeonView.activate_or_new_version_button(conn, dungeon, nil)))
    assert Regex.match?(~r{Test Crawl}, inspect(DungeonView.activate_or_new_version_button(conn, dungeon, nil)))
    refute Regex.match?(~r{Your current crawl will be lost}, inspect(DungeonView.activate_or_new_version_button(conn, dungeon, nil)))

    di = insert_stubbed_dungeon_instance(%{active: true})
    instance = Repo.preload(di, :levels).levels |> Enum.at(0)
    location = insert_player_location(%{level_instance_id: instance.id, user_id_hash: "testhash"})
    assert Regex.match?(~r{Test Crawl}, inspect(DungeonView.activate_or_new_version_button(conn, dungeon, location)))
    assert Regex.match?(~r{Your current crawl will be lost}, inspect(DungeonView.activate_or_new_version_button(conn, dungeon, location)))
  end

  test "activate_or_new_version_button/2 renders nothing if a new version already exists", %{conn: conn} do
    dungeon = insert_stubbed_dungeon()
    _new_version = insert_stubbed_dungeon(%{previous_version_id: dungeon.id})
    refute DungeonView.activate_or_new_version_button(conn, dungeon, nil)
  end

  test "activate_or_new_version_button/2 renders new_version if dungeon active", %{conn: conn} do
    dungeon = insert_stubbed_dungeon()
    assert Regex.match?(~r{New Version}, inspect(DungeonView.activate_or_new_version_button(conn, dungeon, nil)))
  end

  test "adjacent_level_names/1" do
    level_1 = insert_stubbed_level()
    level_2 = insert_stubbed_level(%{number: 2, dungeon_id: level_1.dungeon_id, number_south: level_1.number, number_west: level_1.number})

    assert {:safe,
             """
             <table class=\"table table-sm compact-table\">
               <tr><td>North:</td><td></td></tr>\n  <tr><td>South:</td><td>1 - Stubbed</td></tr>
               <tr><td>West:</td><td>1 - Stubbed</td></tr>
               <tr><td>East:</td><td></td></tr>
             </table>
             """
             } = DungeonView.adjacent_level_names(level_2)
  end

  test "title_level_name/1 returns a name and number for the title level" do
    level = insert_stubbed_level(%{name: "Map", number: 2})
    assert "<no levels>" == DungeonView.title_level_name(nil)
    assert "2 Map" == DungeonView.title_level_name(level)
  end

  test "td_status/1" do
    assert {:safe, "<td title=\"\">queued</td>\n"} ==
             DungeonView.td_status(%{status: "queued", details: nil})
    assert {:safe, "<td title=\"Oof\">failed*</td>\n"} ==
             DungeonView.td_status(%{status: "failed", details: "Oof"})
  end

  test "import_character_row/2" do
    assert {:safe,
      """
      <div class="row">
        <div class="col-2">
          <strong>Character:</strong>
        </div>
        <div class="col">
          <div style="width: 100%"><pre class="tile_template_preview">A</pre></div>
        </div>
        <div class="col">
          <div style="width: 100%"><pre class="tile_template_preview">B</pre></div>
        </div>
      </div>
      """
    } == DungeonView.import_character_row("A", "B")
  end

  test "import_sound_effect_row/2" do
    assert {:safe,
             """
             <div class="row">
               <div class="col-2">
                 <strong>Zzfx Params:</strong>
               </div>
               <div class="col">
                 <div style="width: 100%"><div class="input-group">
               <div class="input-group-prepend user-select-none">
                 <span class="input-group-text play-effect smaller" title="Click to preview the sound effect">▶</span>
               </div>
               <input type="text" class="form-control smaller" disabled=true value="A"></input>
             </div>
             </div>
               </div>
               <div class="col">
                 <div style="width: 100%"><div class="input-group">
               <div class="input-group-prepend user-select-none">
                 <span class="input-group-text play-effect smaller" title="Click to preview the sound effect">▶</span>
               </div>
               <input type="text" class="form-control smaller" disabled=true value="B"></input>
             </div>
             </div>
               </div>
             </div>
             """
           } == DungeonView.import_sound_effect_row("A", "B")
  end

  test "import_field_row/3" do
    assert "" == DungeonView.import_field_row("Field Name", "A", "A")
    assert {:safe,
      """
      <div class="row">
        <div class="col-2">
          <strong>Field Name:</strong>
        </div>
        <div class="col">
          <div style="width: 100%">A</div>
        </div>
        <div class="col">
          <div style="width: 100%">B</div>
        </div>
      </div>
      """
    } == DungeonView.import_field_row("Field Name", "A", "B")
  end

  test "waiting_or_dungeon_link/2", %{conn: conn} do
    # with a dungeon
    import = %{dungeon_id: 123, dungeon: %{name: "Test"}}
    assert "<a href=\"/editor/dungeons/123\">Test</a>" ==
             Phoenix.HTML.safe_to_string(DungeonView.waiting_or_dungeon_link(conn, import))

    # when waiting
    import = %{dungeon_id: nil, id: 1, status: :waiting}
    assert "<a class=\"btn btn-info btn-sm\" href=\"/editor/dungeons/import/1\">Update</a>" ==
             Phoenix.HTML.safe_to_string(DungeonView.waiting_or_dungeon_link(conn, import))

    # when failed
    import = %{dungeon_id: nil, status: :failed}
    assert ""  == DungeonView.waiting_or_dungeon_link(conn, import)
  end
end

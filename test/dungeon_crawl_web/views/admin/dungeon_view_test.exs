defmodule DungeonCrawlWeb.Admin.DungeonViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  import DungeonCrawlWeb.Admin.DungeonView
  alias DungeonCrawl.DungeonInstances

  test "level_header_links/4", %{conn: conn} do
    dungeon_instance = insert_stubbed_dungeon_instance()
    level_no_instance = insert_stubbed_level(%{dungeon_id: dungeon_instance.dungeon_id, number: 2})
    DungeonInstances.create_level_header(level_no_instance, dungeon_instance.id)
    dungeon_instance = Repo.preload(dungeon_instance, [:dungeon, [level_headers: [:levels, :level]]])
    current_level = 1

    assert """
             <a class="nav-link small active"
                id="level1-tab"
                href="/admin/dungeons/#{ dungeon_instance.dungeon_id }?instance_id=#{ dungeon_instance.id }&level=1"
                aria-controls="level1"
                aria-orientation="vertical"
                aria-selected="true">
               &nbsp; (20x20) 1 - Stubbed
             </a>

             <span class="nav-link small "
                id="level2-tab"
                aria-controls="level2"
                aria-orientation="vertical"
                aria-selected="true"
                title="No level instances exist currently">
               &nbsp; (20x20) 2 - Stubbed
             </span>
           """ ==
      level_header_links(conn, dungeon_instance, current_level, dungeon_instance.dungeon)
  end
end

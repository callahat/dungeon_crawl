defmodule DungeonCrawlWeb.CrawlerViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.CrawlerView

  alias DungeonCrawl.Admin

  test "can_start_new_instance/1", %{conn: _conn} do
    map_set_instance = insert_stubbed_map_set_instance(%{active: true})

    assert CrawlerView.can_start_new_instance(map_set_instance.map_set_id)

    Admin.update_setting(%{max_instances: 1})
    refute CrawlerView.can_start_new_instance(map_set_instance.map_set_id)
  end
end

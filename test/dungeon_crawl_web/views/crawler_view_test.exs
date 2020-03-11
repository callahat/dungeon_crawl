defmodule DungeonCrawlWeb.CrawlerViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.CrawlerView

  alias DungeonCrawl.Admin

  test "can_start_new_instance/1", %{conn: conn} do
    instance = insert_stubbed_dungeon_instance(%{active: true})

    assert CrawlerView.can_start_new_instance(instance.map_id)

    Admin.update_setting(%{max_instances: 1})
    refute CrawlerView.can_start_new_instance(instance.map_id)
  end
end

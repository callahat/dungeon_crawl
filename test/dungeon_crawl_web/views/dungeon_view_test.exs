defmodule DungeonCrawlWeb.DungeonViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawlWeb.DungeonView

  alias DungeonCrawl.Admin

  test "can_start_new_instance/1", %{conn: _conn} do
    dungeon_instance = insert_stubbed_dungeon_instance(%{active: true})

    assert DungeonView.can_start_new_instance(dungeon_instance.dungeon_id)

    Admin.update_setting(%{max_instances: 1})
    refute DungeonView.can_start_new_instance(dungeon_instance.dungeon_id)
  end
end

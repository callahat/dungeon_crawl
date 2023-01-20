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

  describe "favorite_star/2" do
    test "a user that is not signed in" do
      assert DungeonView.favorite_star(%{favorited: nil, line_identifier: 1}, false) == ""
    end

    test "a signed in user that has not favorited the dungeon" do
      assert DungeonView.favorite_star(%{favorited: false, line_identifier: 1}, true) ==
              ~s|<i class="fa fa-star-o" aria-hidden="true" phx-click="favorite_1"></i>\n|
    end

    test "a signed in user that has favorited the dungeon" do
      assert DungeonView.favorite_star(%{favorited: true, line_identifier: 1}, true) ==
               ~s|<i class="fa fa-star" aria-hidden="true" phx-click="unfavorite_1"></i>\n|
    end
  end

  describe "dungeon_pin/2" do
    test "admin user and the dungeon is pinned" do
      assert DungeonView.dungeon_pin(%{pinned: true, line_identifier: 1}, true) ==
               ~s|<i class="fa fa-thumb-tack" aria-hidden="true" phx-click="unpin_1"></i>\n|
    end

    test "admin user and the dungeon is not pinned" do
      assert DungeonView.dungeon_pin(%{pinned: false, line_identifier: 1}, true) ==
               ~s|<i class="fa fa-circle-o" aria-hidden="true" phx-click="pin_1"></i>\n|
    end

    test "non admin user and the dungeon is pinned" do
      assert DungeonView.dungeon_pin(%{pinned: true, line_identifier: 1}, false) ==
               ~s|<i class="fa fa-thumb-tack" aria-hidden="true" ></i>\n|
    end

    test "non admin user and the dungeon is not pinned" do
      assert DungeonView.dungeon_pin(%{pinned: false, line_identifier: 1}, false) == ""
    end
  end
end

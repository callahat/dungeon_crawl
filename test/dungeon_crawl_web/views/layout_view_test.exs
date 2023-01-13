defmodule DungeonCrawlWeb.LayoutViewTest do
  use DungeonCrawlWeb.ConnCase, async: true

  alias DungeonCrawl.Admin
  
  import DungeonCrawlWeb.LayoutView

  test "main_tag_class/1" do
    assert main_tag_class(%{sidebar_col: 3}) == "ml-sm-auto col-md-9 col-lg-9 px-4"
    assert main_tag_class(%{sidebar_col: 2}) == "ml-sm-auto col-md-10 col-lg-10 px-4"
    assert main_tag_class(%{}) == "ml-sm-auto col-md-12 col-lg-12 px-4"
  end

  test "alert_class/1" do
    assert alert_class(%{request_path: "/dungeons"}) == "alert-margin-l-3"
    assert alert_class(%{request_path: "/something/else"}) == ""
    assert alert_class(%{}) == ""
  end

  test "user_can_edit_dungeons/1" do
    assert user_can_edit_dungeons(%{is_admin: true})
    assert user_can_edit_dungeons(%{is_admin: false})

    Admin.update_setting(%{non_admin_dungeons_enabled: false})
    assert user_can_edit_dungeons(%{is_admin: true})
    refute user_can_edit_dungeons(%{is_admin: false})
  end
end

defmodule DungeonCrawlWeb.LayoutView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Admin

  def main_tag_class(assigns) do
    if Map.get(assigns, :sidebar_present_md) do
      "ml-sm-auto col-md-9 col-lg-9 px-4"
    else
      "ml-sm-auto col-md-12 col-lg-12 px-4"
    end
  end

  def user_can_edit_dungeons(user) do
    user.is_admin or Admin.get_setting().non_admin_dungeons_enabled
  end
end

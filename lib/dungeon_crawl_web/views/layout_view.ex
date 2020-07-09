defmodule DungeonCrawlWeb.LayoutView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Admin

  def main_tag_class(assigns) do
    case Map.get(assigns, :sidebar_col) do
      3 -> "ml-sm-auto col-md-9 col-lg-9 px-4"
      2 -> "ml-sm-auto col-md-10 col-lg-10 px-4"
      _ -> "ml-sm-auto col-md-12 col-lg-12 px-4"
    end
  end

  def user_can_edit_dungeons(user) do
    user.is_admin or Admin.get_setting().non_admin_dungeons_enabled
  end
end

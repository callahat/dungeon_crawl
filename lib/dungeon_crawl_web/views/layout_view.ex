defmodule DungeonCrawlWeb.LayoutView do
  use DungeonCrawl.Web, :view

  def main_tag_class(assigns) do
    if Map.get(assigns, :sidebar_present_md) do
      "ml-sm-auto col-md-9 col-lg-9 px-4"
    else
      "ml-sm-auto col-md-12 col-lg-12 px-4"
    end
  end
end

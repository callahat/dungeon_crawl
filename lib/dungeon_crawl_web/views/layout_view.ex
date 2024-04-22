defmodule DungeonCrawlWeb.LayoutView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Admin

  def main_tag_class(assigns) do
    case Map.get(assigns, :sidebar_col) do
      3 -> "ml-sm-auto col-md-9 col-lg-9 px-4"
      2 -> "ml-sm-auto col-md-10 col-lg-10 px-4" # this might not be used anymore anywhere
      _ -> "ml-sm-auto col-md-12 col-lg-12 px-4"
    end
  end

  def alert_p(conn, nil, _alert_type), do: ""
  def alert_p(conn, flash, type),
      do: ~s|<p class="alert alert-#{type} #{ alert_class(conn) } %>" role="alert">#{ flash }</p>|

  def alert_class(conn) do
    case Map.get(conn, :request_path) do
      "/dungeons" -> "alert-margin-l-3"
      _ -> ""
    end
  end

  def user_can_edit_dungeons(user) do
    user.is_admin or Admin.get_setting().non_admin_dungeons_enabled
  end

  def in_crawler_controller?(conn) do
    controller_module(conn) == Elixir.DungeonCrawlWeb.CrawlerController
  end

  def hide_standard_flash(conn) do
    Map.get(conn, :request_path) == "/editor/dungeons/import" ||
      Map.get(conn, :request_path) == "/editor/dungeons/export"
  end
end

defmodule DungeonCrawlWeb.ScoreView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Account

  def score_filter_link(conn, link_text, filter_params) do
    link(link_text,
         to: Routes.score_path(conn, :index, filter_params),
         title: "Hi scores for `#{link_text}`")
  end
end

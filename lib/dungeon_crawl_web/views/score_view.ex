defmodule DungeonCrawlWeb.ScoreView do
  use DungeonCrawl.Web, :view

  alias DungeonCrawl.Account

  def score_filter_link(conn, link_text, filter_params) do
    link(link_text,
         to: Routes.score_path(conn, :index, filter_params),
         title: "Hi scores for `#{link_text}`")
  end

  def format_duration(nil), do: "none"

  def format_duration(in_seconds) do
    days = div in_seconds, 60*60*24
    remainder = rem in_seconds, 60*60*24
    hours = div remainder, 60*60
    remainder = rem remainder, 60*60
    minutes = div remainder, 60
    seconds = rem in_seconds, 60
    _format_duration(days, hours, minutes, seconds)
  end

  def _format_duration(0, 0, minutes, seconds) do
    "#{pad(minutes)}' #{pad(seconds)}\""
  end
  def _format_duration(0, hours, minutes, seconds) do
    "#{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}"
  end
  def _format_duration(1, hours, minutes, seconds) do
    "1 day, #{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}"
  end
  def _format_duration(days, hours, minutes, seconds) do
    "#{days} days, #{pad(hours)}:#{pad(minutes)}:#{pad(seconds)}"
  end

  defp pad(number), do: :io_lib.format('~2..0B', [number])
end

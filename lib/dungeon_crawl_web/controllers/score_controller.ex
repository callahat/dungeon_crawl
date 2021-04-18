defmodule DungeonCrawlWeb.ScoreController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Scores
  alias DungeonCrawl.Scores.Score
  alias DungeonCrawl.Dungeon
  alias DungeonCrawl.Account

  def index(conn, %{"map_set_id" => map_set_id}) do
    map_set = Dungeon.get_map_set(map_set_id)
    scores = Scores.top_scores_for_map_set(map_set_id)
    render(conn, "index.html", scores: scores, details: %{who: map_set.name})
  end

  def index(conn, %{"user_id" => user_id}) do
    user = Account.get_user(user_id)
    scores = Scores.top_scores_for_player(user.user_id_hash)
    render(conn, "index.html", scores: scores, details: %{who: user.name})
  end

  def index(conn, _params) do
    scores = Scores.list_scores()
    render(conn, "index.html", scores: scores, details: %{})
  end
end

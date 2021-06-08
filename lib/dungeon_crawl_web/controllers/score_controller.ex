defmodule DungeonCrawlWeb.ScoreController do
  use DungeonCrawl.Web, :controller

  alias DungeonCrawl.Scores
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Account

  def index(conn, %{"dungeon_id" => dungeon_id, "score_id" => score_id}) do
    dungeon = Dungeons.get_dungeon(dungeon_id)
    other_dungeons = Dungeons.get_dungeons(dungeon.line_identifier)
    scores = Scores.top_scores_for_dungeon(dungeon_id)
    score = Repo.preload(Scores.get_ranked_score(dungeon_id, score_id), :dungeon)
    render(conn, "index.html", scores: scores, details: %{who: dungeon.name,
                                                          other_dungeons: other_dungeons,
                                                          dungeon_id: dungeon.id,
                                                          score: score})
  end

  def index(conn, %{"dungeon_id" => dungeon_id}) do
    dungeon = Dungeons.get_dungeon(dungeon_id)
    other_dungeons = Dungeons.get_dungeons(dungeon.line_identifier)
    scores = Scores.top_scores_for_dungeon(dungeon_id)
    render(conn, "index.html", scores: scores, details: %{who: dungeon.name,
                                                          other_dungeons: other_dungeons,
                                                          dungeon_id: dungeon.id})
  end

  def index(conn, %{"user_id" => user_id}) do
    user = Account.get_user(user_id)
    scores = Scores.top_scores_for_player(user.user_id_hash)
    render(conn, "index.html", scores: scores, details: %{who: user.name})
  end

  def index(conn, _params) do
    scores = Scores.list_new_scores()
    render(conn, "index.html", scores: scores, details: %{})
  end
end

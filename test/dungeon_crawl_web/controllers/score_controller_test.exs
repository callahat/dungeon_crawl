defmodule DungeonCrawlWeb.ScoreControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Scores

  setup %{conn: conn} do
    dungeon_1 = insert_dungeon(%{name: "DungeonOne", line_identifier: 1})
    dungeon_2 = insert_dungeon(%{name: "DungeonTwo", line_identifier: 2})
    user_1 = insert_user(%{name: "UserOne", user_id_hash: "one"})
    user_2 = insert_user(%{name: "UserTwo", user_id_hash: "two"})

    {:ok, score1} = Scores.create_score(%{dungeon_id: dungeon_1.id, user_id_hash: user_1.user_id_hash, score: 1})
    Scores.create_score(%{dungeon_id: dungeon_1.id, user_id_hash: user_1.user_id_hash, score: 2})
    Scores.create_score(%{dungeon_id: dungeon_2.id, user_id_hash: user_1.user_id_hash, score: 3})
    Scores.create_score(%{dungeon_id: dungeon_2.id, user_id_hash: user_2.user_id_hash, score: 4})

    {:ok, conn: conn, user_1: user_1, user_2: user_2, dungeon_1: dungeon_1, dungeon_2: dungeon_2, score: score1}
  end

  describe "index" do
    test "lists all scores", %{conn: conn} do
      conn = get(conn, score_path(conn, :index))
      assert html_response(conn, 200) =~ "<h5>High Scores</h5>"
    end

    test "lists all scores for dungeon and specific score", %{conn: conn, dungeon_1: dungeon_1, dungeon_2: dungeon_2} do
      conn = get(conn, score_path(conn, :index, dungeon_id: dungeon_1.id))
      assert html_response(conn, 200) =~ "High Scores for #{dungeon_1.name}"
      assert html_response(conn, 200) =~ "Other Versions"
      assert html_response(conn, 200) =~ "* #{dungeon_1.name}"
      refute html_response(conn, 200) =~ "hilighted-score"
      refute html_response(conn, 200) =~ dungeon_2.name
    end

    test "lists all scores for dungeon", %{conn: conn, dungeon_1: dungeon_1, score: score} do
      conn = get(conn, score_path(conn, :index, dungeon_id: dungeon_1.id, score_id: score.id))
      assert html_response(conn, 200) =~ "hilighted-score"
      assert html_response(conn, 200) =~ "High Scores for #{dungeon_1.name}"
      assert html_response(conn, 200) =~ "Other Versions"
      assert html_response(conn, 200) =~ "* #{dungeon_1.name}"
    end

    test "lists all scores for a player", %{conn: conn, user_1: user_1, user_2: user_2} do
      conn = get(conn, score_path(conn, :index, user_id: user_2.id))
      assert html_response(conn, 200) =~ "High Scores for #{user_2.name}"
      refute html_response(conn, 200) =~ user_1.name
    end
  end
end

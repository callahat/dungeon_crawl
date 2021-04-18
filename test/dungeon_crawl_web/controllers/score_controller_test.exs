defmodule DungeonCrawlWeb.ScoreControllerTest do
  use DungeonCrawlWeb.ConnCase

  alias DungeonCrawl.Scores

  setup %{conn: conn} do
    map_set_1 = insert_map_set(%{name: "DungeonOne"})
    map_set_2 = insert_map_set(%{name: "DungeonTwo"})
    user_1 = insert_user(%{name: "UserOne", user_id_hash: "one"})
    user_2 = insert_user(%{name: "UserTwo", user_id_hash: "two"})

    Scores.create_score(%{map_set_id: map_set_1.id, user_id_hash: user_1.user_id_hash, score: 1})
    Scores.create_score(%{map_set_id: map_set_1.id, user_id_hash: user_1.user_id_hash, score: 2})
    Scores.create_score(%{map_set_id: map_set_2.id, user_id_hash: user_1.user_id_hash, score: 3})
    Scores.create_score(%{map_set_id: map_set_2.id, user_id_hash: user_2.user_id_hash, score: 4})

    {:ok, conn: conn, user_1: user_1, user_2: user_2, map_set_1: map_set_1, map_set_2: map_set_2}
  end

  describe "index" do
    test "lists all scores", %{conn: conn} do
      conn = get(conn, score_path(conn, :index))
      assert html_response(conn, 200) =~ "<h5>High Scores</h5>"
    end

    test "lists all scores for map set", %{conn: conn, map_set_1: map_set_1, map_set_2: map_set_2} do
      conn = get(conn, score_path(conn, :index, map_set_id: map_set_1.id))
      assert html_response(conn, 200) =~ "High Scores for #{map_set_1.name}"
      refute html_response(conn, 200) =~ map_set_2.name
    end


    test "lists all scores for a player", %{conn: conn, user_1: user_1, user_2: user_2} do
      conn = get(conn, score_path(conn, :index, user_id: user_2.id))
      assert html_response(conn, 200) =~ "High Scores for #{user_2.name}"
      refute html_response(conn, 200) =~ user_1.name
    end
  end
end

defmodule DungeonCrawl.ScoresTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Scores

  describe "scores" do
    alias DungeonCrawl.Scores.Score

    @valid_attrs %{duration: 123, result: "win", score: 42, victory: true, user_id_hash: "sdf", deaths: 1}
    @invalid_attrs %{result: nil, score: nil, steps: nil, victory: nil}

    def score_fixture(attrs \\ %{}) do
      dungeon = if attrs[:dungeon_id],
                  do: %{id: attrs[:dungeon_id]},
                  else: insert_dungeon()

      {:ok, score} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:dungeon_id, dungeon.id)
        |> Scores.create_score()

      score
    end

    test "list_scores/0 returns scores" do
      score = Repo.preload(score_fixture(), :dungeon)
      assert Scores.list_scores() == [%{score | place: 1}]
    end

    test "list_new_scores/0 returns most recent scores" do
      Enum.each(0..15, fn i -> score_fixture(%{score: i}) end)
      scores = Scores.list_new_scores()
      assert length(scores) == 10
      [newest | _] = scores
      [oldest | _] = Enum.reverse(scores)
      assert newest.id > oldest.id
    end

    test "top_scores_for_dungeon/1 returns scores for given dungeon" do
      dungeon_2 = insert_dungeon()
      score_fixture()
      score = Repo.preload(score_fixture(%{dungeon_id: dungeon_2.id}), :dungeon)
      assert Scores.top_scores_for_dungeon(dungeon_2.id) == [%{score | place: 1}]
    end

    test "top_scores_for_dungeon/2 returns top scores for given dungeon" do
      dungeon_2 = insert_dungeon()
      score_fixture(%{score: 500})
      Enum.each(0..15, fn i -> score_fixture(%{score: i, dungeon_id: dungeon_2.id}) end)
      assert length(Scores.top_scores_for_dungeon(dungeon_2.id)) == 10
      assert [%{score: 15, place: 1}] = Scores.top_scores_for_dungeon(dungeon_2.id, 1)
      assert [%{score: 15, place: 1}, %{score: 14, place: 2}] = Scores.top_scores_for_dungeon(dungeon_2.id, 2)
    end

    test "top_scores_for_player/1 returns top scores for given user_id_hash" do
      user = insert_user()
      score = Repo.preload(score_fixture(%{user_id_hash: user.user_id_hash}), :dungeon)
              |> Map.put(:user, Map.put(user, :password, nil))
      score_fixture(%{user_id_hash: "notme"})
      assert Scores.top_scores_for_player(user.user_id_hash) == [%{ score | place: nil }]
    end

    test "get_ranked_score/2 returns the ranked score" do
      dungeon_2 = insert_dungeon()
      score_fixture(%{score: 500})
      Enum.each(0..15, fn i -> score_fixture(%{score: i * 2, dungeon_id: dungeon_2.id}) end)
      score = score_fixture(%{score: 7, dungeon_id: dungeon_2.id})

      assert %{ score | place: 13 } == Scores.get_ranked_score(dungeon_2.id, score.id)
      refute Scores.get_ranked_score(dungeon_2.id, score.id + 1)
    end

    test "create_score/1 with valid data creates a score" do
      dungeon = insert_dungeon()
      assert {:ok, %Score{} = score} = Scores.create_score(Map.put(@valid_attrs, :dungeon_id, dungeon.id))
      assert %{duration: 123,
               result: "win",
               score: 42,
               victory: true,
               deaths: 1} = score
    end

    test "create_score/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scores.create_score(@invalid_attrs)
    end

    test "change_score/1 returns a score changeset" do
      score = score_fixture()
      assert %Ecto.Changeset{} = Scores.change_score(score)
    end
  end
end

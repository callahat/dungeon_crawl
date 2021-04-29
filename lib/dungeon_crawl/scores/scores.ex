defmodule DungeonCrawl.Scores do
  @moduledoc """
  The Scores context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Scores.Score

  @doc """
  Returns the list of scores.

  ## Examples

      iex> list_scores()
      [%Score{}, ...]

  """
  def list_scores do
    _from_ranked_scores_subquery()
    |> _order_score_descending()
    |> _preload_map_set_and_user()
    |> Repo.all()
  end

  @doc """
  Returns the list of most recent scores.
  """
  def list_new_scores(top \\ 10) do
    _order_recent_descending(DungeonCrawl.Scores.Score)
    |> _limit(top)
    |> _preload_map_set_and_user()
    |> Repo.all()
  end

  @doc """
  Returns the list of scores for the given map set.
  """
  def top_scores_for_map_set(map_set_id, top \\ 10) do
    _from_ranked_scores_subquery(map_set_id)
    |> _order_score_descending()
    |> _limit(top)
    |> _preload_map_set_and_user()
    |> Repo.all()
  end

  @doc """
  Returns the list of scores for the given player.
  """
  def top_scores_for_player(user_id_hash, top \\ 10) do
    _order_score_descending(DungeonCrawl.Scores.Score)
    |> _filter_on_user_id_hash(user_id_hash)
    |> _limit(top)
    |> _preload_map_set_and_user()
    |> Repo.all()
  end

  @doc """
  Returns the score with placement for the map set.
  """
  def get_ranked_score(map_set_id, score_id) do
    Repo.one from o in _from_ranked_scores_subquery(map_set_id),
             where: o.id == ^score_id,
             left_join: u in DungeonCrawl.Account.User, on: u.user_id_hash == o.user_id_hash,
             select_merge: %{user: u}
  end

  defp _from_ranked_scores_subquery() do
    subquery(from s in Score,
             select: %{ s | place: row_number() |> over(order_by: [desc: s.score])})
  end

  defp _from_ranked_scores_subquery(map_set_id) do
    subquery(from s in Score,
             select: %{ s | place: row_number() |> over(order_by: [desc: s.score])},
             where: s.map_set_id == ^map_set_id)
  end

  defp _preload_map_set_and_user(query) do
    from s in query,
    left_join: u in DungeonCrawl.Account.User, on: u.user_id_hash == s.user_id_hash,
    select_merge: %{user: u},
    preload: [:map_set]
  end

  defp _order_score_descending(query) do
    from s in query,
    order_by: [desc: s.score]
  end

  defp _order_recent_descending(query) do
    from s in query,
    order_by: [desc: s.id]
  end

  defp _filter_on_user_id_hash(query, user_id_hash) do
    from s in query,
    where: s.user_id_hash == ^user_id_hash
  end

  defp _limit(query, limit) do
    from s in query,
    limit: ^limit
  end

  @doc """
  Creates a score.

  ## Examples

      iex> create_score(%{field: value})
      {:ok, %Score{}}

      iex> create_score(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_score(attrs \\ %{}) do
    %Score{}
    |> Score.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking score changes.

  ## Examples

      iex> change_score(score)
      %Ecto.Changeset{source: %Score{}}

  """
  def change_score(%Score{} = score) do
    Score.changeset(score, %{})
  end
end

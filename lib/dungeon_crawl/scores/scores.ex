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
    _from_scores()
    |> _order_score_descending()
    |> Repo.all()
  end

  @doc """
  Returns the list of scores for the given map set.
  """
  def top_scores_for_map_set(map_set_id, top \\ 10) do
    _from_scores()
    |> _order_score_descending()
    |> _filter_on_map_set_id(map_set_id)
    |> _limit(top)
    |> Repo.all()
  end

  @doc """
  Returns the list of scores for the given player.
  """
  def top_scores_for_player(user_id_hash, top \\ 10) do
    _from_scores()
    |> _order_score_descending()
    |> _filter_on_user_id_hash(user_id_hash)
    |> _limit(top)
    |> Repo.all()
  end

  defp _from_scores(query \\ DungeonCrawl.Scores.Score) do
    from s in query,
    left_join: u in DungeonCrawl.Account.User, on: u.user_id_hash == s.user_id_hash,
    select_merge: %{user: u},
    preload: [:map_set]
  end

  defp _order_score_descending(query) do
    from s in query,
    order_by: [desc: s.score]
  end

  defp _filter_on_map_set_id(query, map_set_id) do
    from s in query,
    where: s.map_set_id == ^map_set_id
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

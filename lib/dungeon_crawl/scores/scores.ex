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
    Repo.all(from s in DungeonCrawl.Scores.Score,
             order_by: [desc: s.score])
  end

  @doc """
  Returns the list of scores for the given map set.
  """
  def top_scores_for_map_set(map_set_id, top \\ 10) do
    Repo.all(from s in DungeonCrawl.Scores.Score,
             where: s.map_set_id == ^map_set_id,
             order_by: [desc: s.score],
             limit: ^top)
  end

  @doc """
  Returns the list of scores for the given player.
  """
  def top_scores_for_player(user_id_hash, top \\ 10) do
    Repo.all(from s in DungeonCrawl.Scores.Score,
             where: s.user_id_hash == ^user_id_hash,
             order_by: [desc: s.score],
             limit: ^top)
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

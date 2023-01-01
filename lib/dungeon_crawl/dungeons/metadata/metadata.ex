defmodule DungeonCrawl.Dungeons.Metadata do

  @moduledoc """
  The Dungeon Metadata context.
  Contains functionality for favoriting and pinning dungeons, to aid in listing
  them in a useful manner.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Dungeons.Metadata.FavoriteDungeon

  @doc """
  Favorites a dungeon for a user.

  ## Examples

      iex> favorite(%Dungeon{}, %User{})
      :ok
  """
  def favorite(%Dungeon{line_identifier: line_identifier}, %User{user_id_hash: user_id_hash}) do
    favorite(line_identifier, user_id_hash)
  end

  def favorite(line_identifier, user_id_hash) do
    %FavoriteDungeon{}
    |> FavoriteDungeon.changeset(%{line_identifier: line_identifier, user_id_hash: user_id_hash})
    |> Repo.insert()
  end

  @doc """
  Unfavorites a dungeon for a user.

  ## Examples

      iex> unfavorite(%Dungeon{}, %User{})
      :ok
  """
  def unfavorite(%Dungeon{line_identifier: line_identifier}, %User{user_id_hash: user_id_hash}) do
    unfavorite(line_identifier, user_id_hash)
  end

  def unfavorite(line_identifier, user_id_hash) do
    if favorite = Repo.get_by(FavoriteDungeon, %{line_identifier: line_identifier, user_id_hash: user_id_hash}) do
      Repo.delete(favorite)
      {:ok, favorite}
    else
      {:error, "favorite not found"}
    end
  end
end
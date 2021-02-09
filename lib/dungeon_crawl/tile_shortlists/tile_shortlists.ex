defmodule DungeonCrawl.TileShortlists do
  @moduledoc """
  The TileShortlists context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account.User
  alias DungeonCrawl.TileShortlists.TileShortlist

  @max_size 20

  @doc """
  Returns the list of tile_shortlists.

  ## Examples

      iex> list_tiles(%User{})
      [%TileShortlist{}, ...]

  """
  def list_tiles() do
    Repo.all(TileShortlist)
  end
  def list_tiles(%User{id: user_id}) do
    list_tiles(user_id)
  end
  def list_tiles(user_id) do
    Repo.all(from ts in TileShortlist,
             where: ts.user_id == ^user_id,
             order_by: [desc: :id])
  end

  @doc """
  Creates a tile_shortlist.

  ## Examples

      iex> create_tile_shortlist(%{field: value})
      {:ok, %TileShortlist{}}

      iex> create_tile_shortlist(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def add_to_shortlist(%User{id: user_id}, attrs) do
    add_to_shortlist(user_id, attrs)
  end
  def add_to_shortlist(user_id, attrs) do
    %TileShortlist{user_id: user_id}
    |> TileShortlist.changeset(attrs)
    |> Repo.insert()
    |> _trim_shortlist()
  end

  defp _trim_shortlist({:error, _changeset} = result), do: result
  defp _trim_shortlist({:ok, shortlist_entry} = result) do
    shortlist = list_tiles(shortlist_entry.user_id)
    trim_size = length(shortlist) - @max_size

    if trim_size > 0 do
      shortlist
      |> Enum.reverse
      |> Enum.take(trim_size)
      |> Enum.each(fn item -> Repo.delete(item) end)
    end

    result
  end
end

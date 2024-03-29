defmodule DungeonCrawl.TileShortlists do
  @moduledoc """
  The TileShortlists context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account.User
  alias DungeonCrawl.StateValue.Parser
  alias DungeonCrawl.TileShortlists.TileShortlist
  alias DungeonCrawl.TileTemplates.TileSeeder

  @max_size 30

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
  Adds a tile to a users shortlist.

  ## Examples

      iex> add_to_shortlist(user, %{field: value})
      {:ok, %TileShortlist{}}

      iex> add_to_shortlist(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def add_to_shortlist(%User{id: user_id}, attrs) do
    add_to_shortlist(user_id, attrs)
  end
  def add_to_shortlist(user_id, attrs) do
    %TileShortlist{user_id: user_id}
    |> TileShortlist.changeset(attrs)
    |> Repo.insert()
    |> _dedupe()
    |> _trim_shortlist()
  end

  defp _dedupe({:error, _changeset} = result), do: result
  defp _dedupe({:ok, shortlist_entry} = result) do
    tile_attrs = Map.take(shortlist_entry, TileShortlist.key_attributes())
                 |> Map.put(:user_id, shortlist_entry.user_id)
    [_added | dupes] = Repo.all(from TileShortlist.attrs_query(tile_attrs), order_by: [desc: :id])
    Enum.each(dupes, fn dupe -> Repo.delete(dupe) end)
    result
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

  @doc """
  Removes a tile from the users shortlist.

  ## Examples

      iex> delete_from_shortlist(user, %{id: id})
      {:ok, %TileShortlist{}}

      iex> delete_from_shortlist(user, %{id: id})
      {:error, <error message>}

  """
  def remove_from_shortlist(%{id: user_id}, id) do
    remove_from_shortlist(user_id, id)
  end
  def remove_from_shortlist(user_id, %{id: id}) do
    remove_from_shortlist(user_id, id)
  end
  def remove_from_shortlist(user_id, id) do
    case Repo.one(from ts in TileShortlist,
                  where: ts.user_id == ^user_id,
                  where: ts.id == ^id) do
      nil -> {:error, "Not found"}
      record -> Repo.delete(record)
    end
  end

  @doc """
  Adds some basic tiles to the users shortlist (if there is room).
  """
  def seed_shortlist(%User{id: user_id}) do
    seed_shortlist(user_id)
  end
  def seed_shortlist(user_id) do
    current_list = list_tiles(user_id)

    basic_tiles = TileSeeder.basic_tiles()
    [
      TileSeeder.generic_colored_key(),
      TileSeeder.generic_colored_door(),
      TileSeeder.ammo(),
      TileSeeder.cash(),
      TileSeeder.gem(),
      TileSeeder.heart(),
      TileSeeder.medkit(),
      TileSeeder.scroll(),
      TileSeeder.bomb(),
      TileSeeder.passage(),
      TileSeeder.stairs_up(),
      TileSeeder.stairs_down(),
      TileSeeder.boulder(),
      TileSeeder.solo_door(),
      basic_tiles["@"],
      basic_tiles[" "],
      basic_tiles["'"],
      basic_tiles["+"],
      basic_tiles["#"],
      basic_tiles["."]
    ]
    |> Enum.each(fn tile ->
         tile_attrs = Map.take(tile, TileShortlist.key_attributes())
                      |> Map.put(:tile_template_id, tile.id)
         add_to_shortlist(user_id, tile_attrs)
       end)

    current_list
    |> Enum.reverse
    |> Enum.each(fn tile ->
         tile_attrs = Map.take(tile, TileShortlist.key_attributes())
         add_to_shortlist(user_id, tile_attrs)
       end)
  end

  @doc """
  Returns a hashed base64 encoded string of the TileShortlist entry.
  """
  def hash(attrs) do
    Base.encode64(:crypto.hash(:sha256, characteristic_string(attrs)))
  end

  defp characteristic_string(attrs) do
    Map.take(attrs, TileShortlist.key_attributes())
    |> Enum.sort()
    |> Enum.map(&_stringified_values/1)
    |> Enum.join("")
  end

  defp _stringified_values({:state, value}) do
    Parser.stringify(value)
  end
  defp _stringified_values({_, value}), do: value
end

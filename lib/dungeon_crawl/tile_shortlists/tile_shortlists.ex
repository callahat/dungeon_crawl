defmodule DungeonCrawl.TileShortlists do
  @moduledoc """
  The TileShortlists context.
  """

  import Ecto.Query, warn: false
  alias DungeonCrawl.Repo

  alias DungeonCrawl.Account.User
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
    |> _dedupe()
    |> _trim_shortlist()
  end

  defp _dedupe({:error, _changeset} = result), do: result
  defp _dedupe({:ok, shortlist_entry} = result) do
    tile_attrs = Map.take(shortlist_entry, TileShortlist.key_attributes())
                 |> Map.put(:user_id, shortlist_entry.user_id)
    [_added | dupes] = Repo.all(from _attrs_query(tile_attrs), order_by: [desc: :id])
    Enum.each(dupes, fn dupe -> Repo.delete(dupe) end)
    result
  end

  defp _attrs_query(attrs) do
    Enum.reduce(attrs, TileShortlist,
      fn {x,y}, query ->
        _attrs_where(query, {x, y})
      end)
  end

  defp _attrs_where(query, {key,   nil}), do: where(query, [ts], is_nil(field(ts, ^key)))
  defp _attrs_where(query, {key, value}), do: where(query, ^[{key, value}])

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
    |> Keyword.values
    |> Enum.join("")
  end
end

defmodule DungeonCrawl.EmptyGenerator do
  @cave_height     40
  @cave_width      80

  @doc """
  Generates an empty dungeon - its all rock/default tile.

  Returns a Map containing a {row, col} tuple and a value. The value will be one
  single character code indicating what is at that coordinate.

  ?\s - Rock
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width) do
    Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
      Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
        Map.put map, {row, col}, ?\s
      end)
    end)
  end

  def stringify(map, cave_width \\ @cave_width) do
    map
    |> _map_to_charlist
    |> Enum.chunk(cave_width)
    |> Enum.map(&(to_string(&1)))
    |> Enum.join("\n")
  end

  defp _map_to_charlist(map) do
    map
    |> Map.to_list
    |> Enum.sort(fn({k1, _}, {k2, _}) -> k1 < k2 end)
    |> Enum.map(fn({_, v}) -> v end)
  end
end

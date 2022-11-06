defmodule DungeonCrawl.DungeonGeneration.Utils do
  @doc """
  Turns a generated level into a displayable string with each row on a line. Needs the row width.
  """
  def stringify(map, cave_width, border_char \\ "") do
    map
    |> _map_to_charlist
    |> Enum.chunk_every(cave_width)
    |> Enum.map(&(_to_string(&1, border_char)))
    |> Enum.join("\n")
  end

  def stringify_with_border(map, cave_width, border_char \\ "`") do
    horiz_border = String.duplicate(border_char, cave_width + 2)

    [
      horiz_border,
      stringify(map, cave_width, border_char),
      horiz_border
    ]
    |> Enum.join("\n")
  end

  defp _map_to_charlist(map) do
    map
    |> Map.to_list
    |> Enum.sort(fn({k1, _}, {k2, _}) -> k1 < k2 end)
    |> Enum.map(fn({_, v}) -> v end)
  end

  defp _to_string(chunk, ""), do: to_string(chunk)
  defp _to_string(chunk, char), do: char <> to_string(chunk) <> char
end

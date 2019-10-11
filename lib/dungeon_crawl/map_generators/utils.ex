defmodule DungeonCrawl.MapGenerators.Utils do
  @doc """
  Turns a generated dungeon into a displayable string with each row on a line. Needs the row width.
  """
  def stringify(map, cave_width) do
    map
    |> _map_to_charlist
    |> Enum.chunk_every(cave_width)
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

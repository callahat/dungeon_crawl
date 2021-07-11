defmodule DungeonCrawl.DungeonGeneration.MapGenerators.Empty do
  @cave_height     40
  @cave_width      80

  @doc """
  Generates an empty level - its all rock/default tile.

  Returns a Map containing a {row, col} tuple and a value. The value will be one
  single character code indicating what is at that coordinate.

  ?\s - Rock
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, _solo_level \\ nil) do
    Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
      Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
        Map.put map, {row, col}, ?\s
      end)
    end)
  end
end

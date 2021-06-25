defmodule DungeonCrawl.MapGenerators.Labrynth do
  @cave_height     39
  @cave_width      79

  #@entities        Enum.to_list(?A..?|)

  @doc """
  Generates a labrynth.

  Returns a Map containing a {row, col} tuple and a value. The value will be one of several
  single character codes indicating what is at that coordinate.

  ?.  - Floor
  ?#  - Wall
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, for_solo \\ false) do
    even_height = rem(cave_height, 2) == 0
    even_width = rem(cave_width, 2) == 0
    map = Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
            Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
              if((even_height && row == cave_height-1) || (even_width && col == cave_width-1)) do
                Map.put map, {row, col}, ?\s
              else
                Map.put map, {row, col}, ?#
              end
            end)
          end)

    initial_seed = _random_coords(cave_height, cave_width)
    seed_queue = _add_to_seed_queue([], initial_seed)

# DungeonCrawl.MapGenerators.Labrynth.generate(5,5) |> DungeonCrawl.MapGenerators.Utils.stringify(5) |> IO.puts
    _dig_tunnels({Map.put(map, initial_seed, ?.), seed_queue, initial_seed})
    |> _stairs_up(for_solo, cave_height, cave_width)
  end

  defp _stairs_up(map, true, cave_height, cave_width) do
    row = :rand.uniform(cave_height) - 1
    col = :rand.uniform(cave_width) - 1

    if map[{row, col}] != ?# && _adjacent_walls(map, row, col) == 3 do
      Map.put(map, {row, col}, ?▟)
    else
      _stairs_up(map, true, cave_height, cave_width)
    end
  end

  defp _stairs_up(map, _, _, _), do: map

  defp _adjacent_walls(map, row, col) do
    [ map[{row+1, col}],
      map[{row-1, col}],
      map[{row, col+1}],
      map[{row, col-1}] ]
    |> Enum.filter(fn char -> char == ?# end)
    |> length
  end

  defp _random_coords(height, width) do
    {:rand.uniform( round(height/2-1) )*2-1,
     :rand.uniform( round(width/2-1) )*2-1}
  end

  # adds a seed to the seed queue
  defp _add_to_seed_queue(queue, {row, col}) do
    queue ++ [{row, col}]
  end

  # if two  steps in each direction is either wall or outside coordinate range
  defp _seed_surrounded(map, {row, col}) do
    map[{row-2, col}] != ?# &&
    map[{row+2, col}] != ?# &&
    map[{row, col-2}] != ?# &&
    map[{row, col+2}] != ?#
  end

  # For each direction 75% chance to dig a tunnel two squares, each end becomes a new seed
  defp _dig_tunnels({map, seed_queue, {row, col}}) do
    {map, seed_queue, {row, col}}
    |> _maybe_dig({-2, 0})
    |> _maybe_dig({ 2, 0})
    |> _maybe_dig({ 0,-2})
    |> _maybe_dig({ 0, 2})
    |> _add_back_to_seed_queue()
    |> _cull_surrounded_seeds()
    |> _pop_from_seed_queue()
    |> _dig_tunnels()
  end

  defp _dig_tunnels({map, [], []}) do
    map
  end

  defp _maybe_dig({map, seed_queue, {row, col}}, {d_row, d_col}) do
    if map[{row + d_row, col + d_col}] == ?# && :rand.uniform(4) == 1 do
      {
        Map.put(map, {row + round(d_row/2), col + round(d_col/2)}, ?.) |> Map.put({row + d_row, col + d_col}, ?.),
        _add_to_seed_queue(seed_queue, {row + d_row, col + d_col}),
        {row, col}
      }
    else
      {map, seed_queue, {row, col}}
    end
  end

  defp _add_back_to_seed_queue({map, seed_queue, last_seed}) do
    {map, _add_to_seed_queue(seed_queue, last_seed)}
  end

  defp _cull_surrounded_seeds({map, seed_queue}) do
    {map, Enum.reject(seed_queue, fn(seed) -> _seed_surrounded(map, seed) end)}
  end

  defp _pop_from_seed_queue({map, [seed | seed_queue]}) do
    {map, seed_queue, seed}
  end

  defp _pop_from_seed_queue({map, []}) do
    {map, [], []}
  end
end

defmodule DungeonCrawl.MapGenerators.Labrynth do
  @cave_height     39
  @cave_width      79

  alias DungeonCrawl.MapGenerators.Entities

  @doc """
  Generates a labrynth.

  Returns a Map containing a {row, col} tuple and a value. The value will be one of several
  single character codes indicating what is at that coordinate.

  ?.  - Floor
  ?#  - Wall
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, solo_level \\ nil) do
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
    _dig_tunnels({Map.put(map, initial_seed, ?.), seed_queue, initial_seed, []})
    |> _stairs_up(solo_level)
    |> _add_entities(solo_level || [])
  end

  defp _stairs_up({map, [stair_coords | dead_ends]}, solo_level) when is_integer(solo_level) do
    {Map.put(map, stair_coords, ?▟), dead_ends}
  end

  defp _stairs_up({map, dead_ends}, _), do: {map, dead_ends}

  defp _add_entities({map, dead_ends}, solo_level) when is_integer(solo_level) do
    max_entities = Enum.min [round(solo_level / 4) + 3, length(dead_ends)]
    min_entities = Enum.min [round(solo_level / 10) + 1, max_entities]
    entities = Entities.randomize(_rand_range(min_entities, max_entities))
    _add_entities({map, dead_ends}, entities)
  end

  defp _add_entities({map, _}, []), do: map

  defp _add_entities({map, []}, _), do: map

  defp _add_entities({map, [entity_coords | dead_ends]}, [entity | entities]) do
    _add_entities({Map.put(map, entity_coords, entity), dead_ends}, entities)
  end

  defp _add_entities({map, _}, _), do: map

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

  # if two  steps in each direction is either not wall or outside coordinate range
  defp _seed_surrounded(map, {row, col}) do
    map[{row-2, col}] != ?# &&
    map[{row+2, col}] != ?# &&
    map[{row, col-2}] != ?# &&
    map[{row, col+2}] != ?#
  end

  defp _dead_end(map, {row, col}) do
    _seed_surrounded(map, {row, col}) &&
      _adjacent_walls(map, row, col) == 3
  end

  # For each direction 75% chance to dig a tunnel two squares, each end becomes a new seed
  defp _dig_tunnels({map, seed_queue, {row, col}, dead_ends}) do
    {map, seed_queue, {row, col}, dead_ends}
    |> _maybe_dig({-2, 0})
    |> _maybe_dig({ 2, 0})
    |> _maybe_dig({ 0,-2})
    |> _maybe_dig({ 0, 2})
    |> _add_back_to_seed_queue()
    |> _cull_surrounded_seeds()
    |> _pop_from_seed_queue()
    |> _dig_tunnels()
  end

  defp _dig_tunnels({map, [], [], dead_ends}) do
    {map, Enum.shuffle(Enum.uniq(dead_ends))}
  end

  defp _maybe_dig({map, seed_queue, {row, col}, dead_ends}, {d_row, d_col}) do
    if map[{row + d_row, col + d_col}] == ?# && :rand.uniform(4) == 1 do
      {
        Map.put(map, {row + round(d_row/2), col + round(d_col/2)}, ?.) |> Map.put({row + d_row, col + d_col}, ?.),
        _add_to_seed_queue(seed_queue, {row + d_row, col + d_col}),
        {row, col},
        dead_ends
      }
    else
      {map, seed_queue, {row, col}, dead_ends}
    end
  end

  defp _add_back_to_seed_queue({map, seed_queue, last_seed, dead_ends}) do
    {map, _add_to_seed_queue(seed_queue, last_seed), dead_ends}
  end

  defp _cull_surrounded_seeds({map, seed_queue, dead_ends}) do
    dead_ends = Enum.reduce(seed_queue, dead_ends, &(_add_any_dead_end(map, &1, &2)))
    {map, Enum.reject(seed_queue, fn(seed) -> _seed_surrounded(map, seed) end), dead_ends}
  end

  defp _pop_from_seed_queue({map, [seed | seed_queue], dead_ends}) do
    {map, seed_queue, seed, dead_ends}
  end

  defp _pop_from_seed_queue({map, [], dead_ends}) do
    {map, [], [], dead_ends}
  end

  defp _add_any_dead_end(map, seed, dead_ends) do
    if _dead_end(map, seed), do: [seed | dead_ends], else: dead_ends
  end

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1
end

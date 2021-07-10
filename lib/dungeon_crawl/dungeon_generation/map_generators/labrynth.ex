defmodule DungeonCrawl.DungeonGeneration.MapGenerators.Labrynth do
  @cave_height     39
  @cave_width      79

  defstruct map: %{},
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            seed_queue: [],
            active_seed: nil,
            dead_ends: []

  alias DungeonCrawl.DungeonGeneration.Entities
  alias DungeonCrawl.DungeonGeneration.MapGenerators.Labrynth

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

    labrynth = %Labrynth{map: Map.put(map, initial_seed, ?.),
                         cave_height: cave_height,
                         cave_width: cave_width,
                         solo_level: solo_level,
                         seed_queue: seed_queue,
                         active_seed: initial_seed}

# DungeonCrawl.DungeonGeneration.MapGenerators.Labrynth.generate(5,5) |> DungeonCrawl.DungeonGeneration.Utils.stringify(5) |> IO.puts
    _dig_tunnels(labrynth)
    |> _stairs_up()
    |> _add_entities()
    |> Map.fetch!(:map)
  end

  defp _stairs_up(%Labrynth{solo_level: nil} = labrynth), do: labrynth
  defp _stairs_up(%Labrynth{map: map, dead_ends: [stair_coords | dead_ends]} = labrynth) do
    %{ labrynth | map: Map.put(map, stair_coords, ?▟), dead_ends: dead_ends }
  end

  defp _add_entities(%Labrynth{solo_level: nil} = labrynth), do: labrynth
  defp _add_entities(%Labrynth{dead_ends: dead_ends, solo_level: solo_level} = labrynth) do
    max_entities = Enum.min [round(solo_level / 4) + 3, length(dead_ends)]
    min_entities = Enum.min [round(solo_level / 10) + 1, max_entities]
    entities = Entities.randomize(_rand_range(min_entities, max_entities))
    _add_entities(labrynth, entities)
  end

  defp _add_entities(%Labrynth{} = labrynth, []), do: labrynth
  defp _add_entities(%Labrynth{dead_ends: []} = labrynth, _), do: labrynth
  defp _add_entities(%Labrynth{map: map, dead_ends: [entity_coords | dead_ends]} = labrynth, [entity | entities]) do
    _add_entities(%{ labrynth | map: Map.put(map, entity_coords, entity), dead_ends: dead_ends}, entities)
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

  defp _dig_tunnels(%Labrynth{seed_queue: [], active_seed: nil, dead_ends: dead_ends} = labrynth) do
    # randomize the dead end list, done digging tunnels
    %{ labrynth | dead_ends: Enum.shuffle(Enum.uniq(dead_ends)) }
  end

  # For each direction 75% chance to dig a tunnel two squares, each end becomes a new seed
  defp _dig_tunnels(%Labrynth{} = labrynth) do
    labrynth
    |> _maybe_dig({-2, 0})
    |> _maybe_dig({ 2, 0})
    |> _maybe_dig({ 0,-2})
    |> _maybe_dig({ 0, 2})
    |> _add_back_to_seed_queue()
    |> _cull_surrounded_seeds()
    |> _pop_from_seed_queue()
    |> _dig_tunnels()
  end

  defp _maybe_dig(%Labrynth{map: map, seed_queue: seed_queue, active_seed: {row, col}} = labrynth, {d_row, d_col}) do
    if map[{row + d_row, col + d_col}] == ?# && :rand.uniform(4) == 1 do
      %{ labrynth | map: Map.merge(map, %{ {row + round(d_row/2), col + round(d_col/2)} => ?.,
                                           {row + d_row, col + d_col} => ?. }),
                    seed_queue: _add_to_seed_queue(seed_queue, {row + d_row, col + d_col}) }
    else
      labrynth
    end
  end

  defp _add_back_to_seed_queue(%Labrynth{seed_queue: seed_queue, active_seed: last_seed} = labrynth) do
    %{ labrynth | seed_queue: _add_to_seed_queue(seed_queue, last_seed)}
  end

  defp _cull_surrounded_seeds(%Labrynth{map: map, seed_queue: seed_queue, dead_ends: dead_ends} = labrynth) do
    %{ labrynth | seed_queue: Enum.reject(seed_queue, fn(seed) -> _seed_surrounded(map, seed) end),
                  dead_ends: Enum.reduce(seed_queue, dead_ends, &(_add_any_dead_end(map, &1, &2)))}
  end

  defp _pop_from_seed_queue(%Labrynth{seed_queue: [seed | seed_queue]} = labrynth) do
    %{ labrynth | seed_queue: seed_queue, active_seed: seed }
  end

  defp _pop_from_seed_queue(%Labrynth{seed_queue: []} = labrynth) do
    %{ labrynth | active_seed: nil }
  end

  defp _add_any_dead_end(map, seed, dead_ends) do
    if _dead_end(map, seed), do: [seed | dead_ends], else: dead_ends
  end

  defp _dead_end(map, {row, col}) do
    _seed_surrounded(map, {row, col}) &&
      _adjacent_walls(map, row, col) == 3
  end

  defp _adjacent_walls(%Labrynth{map: map} = _labrynth, row, col) do
    _adjacent_walls(map, row, col)
  end
  defp _adjacent_walls(map, row, col) do
    [ map[{row+1, col}],
      map[{row-1, col}],
      map[{row, col+1}],
      map[{row, col-1}] ]
    |> Enum.filter(fn char -> char == ?# end)
    |> length
  end

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1
end

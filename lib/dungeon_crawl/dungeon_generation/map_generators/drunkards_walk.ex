defmodule DungeonCrawl.DungeonGeneration.MapGenerators.DrunkardsWalk do
  @edge_buffer        5

  @cave_height     40
  @cave_width      80

  defstruct map: %{},
            floor_needed: 0,
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            current_coords: nil,
            facing: {0, 0},
            sober: false,
            room_coords: [],
            iterations: nil,
            debug: false

  alias DungeonCrawl.DungeonGeneration.Entities
  alias DungeonCrawl.DungeonGeneration.MapGenerators.DrunkardsWalk

  @doc """
  Generates a level using the drunkards walk algorithm.

  Returns a Map containing a {row, col} tuple and a value. The value will be one of several
  single character codes indicating what is at that coordinate.

  ?\s - Rock
  ?.  - Floor
  ?#  - Wall
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, solo_level \\ nil, debug \\ false) do
    map = Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
            Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
              Map.put map, {row, col}, ?\s
            end)
          end)

    starting_coords = _centerish_coord(cave_height, cave_width, 4)
    floor_factor = _rand_range(30, 45) / 100.0
    floor_needed = round(cave_height * cave_width * floor_factor)

    map =
    %DrunkardsWalk{
      map: map,
      current_coords: starting_coords,
      cave_height: cave_height,
      cave_width: cave_width,
      solo_level: solo_level,
      floor_needed: floor_needed,
      iterations: floor_needed * 5,
      debug: debug
    }
    |> _try_placing_floor()
    |> _generate_drunk()
    |> _stairs_up()
    |> _wallify()
    |> _add_entities()
    |> Map.fetch!(:map)

    # for console debugging purposes only
    if debug, do: IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map, cave_width)
    map
  end

  defp _centerish_coord(ch, cw, within) do
    mid_row = round(ch / 2)
    mid_col = round(cw / 2)
    {_rand_range(mid_row - within, mid_row + within), _rand_range(mid_col - within, mid_col + within)}
  end

  # TODO: maybe add bounding rectangles and become sober after n steps or a % of the rectangle is floor
  defp _generate_drunk(drunkards_walk) do
    _generate_drunk(drunkards_walk, _rand_range(10, 300))
    |> _generate_sober
  end
  defp _generate_drunk(drunkards_walk, 0), do: drunkards_walk
  defp _generate_drunk(drunkards_walk, drunkeness) do
    drunkards_walk
    |> _turn
    |> _walk(1)
    |> _generate_drunk(drunkeness - 1)
  end

  defp _generate_sober(%DrunkardsWalk{iterations: 0} = drunkards_walk),
    do: drunkards_walk
  defp _generate_sober(%DrunkardsWalk{floor_needed: i} = drunkards_walk) when i <= 0,
    do: drunkards_walk
  defp _generate_sober(%DrunkardsWalk{iterations: iterations} = drunkards_walk) do
    %{ drunkards_walk | iterations: iterations - 1}
    |> _walk(_rand_range(5, 10))
    |> _generate_drunk
  end

  defp _turn(%DrunkardsWalk{facing: facing} = drunkards_walk) do
    new_facing = [{1, 0}, {-1, 0}, {0, 1}, {0, -1}] -- [facing]
                 |> Enum.random
    %{ drunkards_walk | facing: new_facing }
  end

  defp _walk(%DrunkardsWalk{} = drunkards_walk, 0), do: drunkards_walk
  defp _walk(%DrunkardsWalk{current_coords: {cr, cc}} = drunkards_walk, steps) do
    # puts debugging when running in iex
    _puts_map_debugging(drunkards_walk)

    {fr, fc} = _maybe_adjust_facing(drunkards_walk)

    first_step = Enum.random [{cr + fr, cc}, {cr, cc + fc}]

    # Might be facing diagonally, so first step makes sure it goes adjacent,
    # then if there is a second step it ensures a reachable path by going only
    # orthogonally
    %{drunkards_walk | current_coords: first_step}
    |> _try_placing_floor()
    |> Map.put(:current_coords, { cr + fr, cc + fc})
    |> _try_placing_floor()
    |> _walk(steps - 1)
  end

  defp _maybe_adjust_facing(drunkards_walk) do
    if _near_edge(drunkards_walk),
      do: _face_away_from_edge(drunkards_walk),
      else: drunkards_walk.facing
  end

  defp _near_edge(%{current_coords: {cur_row, cur_col},
                    facing: {fr, fc},
                    cave_height: ch,
                    cave_width: cw}) do
    cur_row <= 2 && fr == -1 ||
      cur_row >= ch - 3 && fr == 1 ||
      cur_col <= 2 && fc == -1 ||
      cur_col >= cw - 3 && fc == 1
  end

  defp _face_away_from_edge(%{current_coords: {cur_row, cur_col},
                              cave_height: ch,
                              cave_width: cw}) do
    # if within 5 from an edge, face away. if there aer two edges, face away from both, 20% chance to pick only one
    dr = _oppose_edge(ch, cur_row, @edge_buffer)
    dc = _oppose_edge(cw, cur_col, @edge_buffer)

    if dr != 0 && dc != 0 do
      case _rand_range(1, 10) do
        10 -> {dr, 0}
         9 -> {0, dc}
         _ -> {dr, dc}
      end
    else
      {dr, dc}
    end
  end

  defp _oppose_edge(max_dimension, current_position, buffer_distance) do
    cond do
      buffer_distance > current_position -> 1
      max_dimension - 1 - buffer_distance < current_position -> -1
      true -> 0
    end
  end

  defp _try_placing_floor(%DrunkardsWalk{map: map,
                                         current_coords: {cur_row, cur_col},
                                         floor_needed: floor_needed} = drunkards_walk) do
    if map[{cur_row, cur_col}] == ?\s do
      %{drunkards_walk | floor_needed: floor_needed - 1}
      |> _replace_tile_at(cur_col, cur_row, ?.)
    else
      drunkards_walk
    end
  end

  defp _stairs_up(%DrunkardsWalk{solo_level: nil} = drunkards_walk), do: drunkards_walk
  defp _stairs_up(%DrunkardsWalk{cave_height: cave_height,
                                 cave_width: cave_width} = drunkards_walk) do
    row = _rand_range(2, cave_height - 3)
    col = _rand_range(2, cave_width - 3)

    %{ drunkards_walk | current_coords: {row, col} }
    |> _drunk_stairs_up(600)
  end

  defp _drunk_stairs_up(drunkards_walk, 0), do: _stairs_up(drunkards_walk)
  defp _drunk_stairs_up(%DrunkardsWalk{current_coords: {row, col}, map: map} = drunkards_walk, count) do
    _puts_map_debugging(drunkards_walk)

    if _valid_stair_placement(map, row, col) do
      _replace_tile_at(drunkards_walk, col, row, ?▟)
    else
      {fr, fc} = _maybe_adjust_facing(drunkards_walk)

      %{ drunkards_walk | current_coords: {row + fr, col + fc}, facing: {fr, fc} }
      |> _turn()
      |> _drunk_stairs_up(count - 1)
    end
  end

  defp _valid_stair_placement(map, row, col) do
    map[{row, col}] == ?\s && _valid_stair_neighbors(map, row, col)
  end

  defp _valid_stair_neighbors(map, row, col) do
    adjacent_floors =
      [ map[{row+1, col}],
        map[{row-1, col}],
        map[{row, col+1}],
        map[{row, col-1}] ]
      |> Enum.filter(fn char -> char == ?. || char == ?\s end)

    Enum.member?(adjacent_floors, ?.) && Enum.member?(adjacent_floors, ?\s)
  end

  defp _replace_tile_at(%DrunkardsWalk{map: map} = drunkards_walk, col, row, new_tile) do
    %{ drunkards_walk | map: Map.put(map, {row, col}, new_tile) }
  end
  defp _replace_tile_at(map, col, row, new_tile) do
    Map.put(map, {row, col}, new_tile)
  end

  defp _wallify(%DrunkardsWalk{map: map} = drunkards_walk) do
    %{ drunkards_walk | map: _wallify(map, drunkards_walk.cave_height, drunkards_walk.cave_width) }
  end
  defp _wallify(map, cave_height, cave_width) do
    _wallify(map, cave_height, cave_width, cave_width)
  end
  defp _wallify(map, -1, -1, _), do: map
  defp _wallify(map, row, -1, cave_width), do: _wallify(map, row - 1, cave_width, cave_width)
  defp _wallify(map, row, col, cave_width) do
    map = if map[{row, col}] == ?\s && _should_be_a_wall(map, row, col),
             do: _replace_tile_at(map, col, row, ?#),
             else: map

    _wallify(map, row, col - 1, cave_width)
  end

  defp _should_be_a_wall(map, row, col) do
    neighbors =
      [ map[{row+1, col}],
        map[{row+1, col+1}],
        map[{row+1, col-1}],
        map[{row-1, col}],
        map[{row-1, col+1}],
        map[{row-1, col-1}],
        map[{row, col-1}],
        map[{row, col+1}] ]
      |> Enum.filter(fn char -> char == ?. || char == ?▟ end)

    neighbors != []
  end

  defp _add_entities(%DrunkardsWalk{solo_level: nil} = drunkards_walk) do
    drunkards_walk
  end
  defp _add_entities(%DrunkardsWalk{solo_level: solo_level,
                                    cave_height: cave_height,
                                    cave_width: cave_width} = drunkards_walk) do
    max_entities = Enum.min [solo_level * 3, round(cave_height * cave_width * 0.15)]
    min_entities = Enum.min [solo_level + 5, max_entities]
    entities = Entities.randomize(_rand_range(min_entities, max_entities))

    _add_entities(drunkards_walk, entities)
  end
  defp _add_entities(%DrunkardsWalk{} = drunkards_walk, []), do: drunkards_walk
  defp _add_entities(%DrunkardsWalk{map: map,
                                    cave_height: cave_height,
                                    cave_width: cave_width} = drunkards_walk,
                     [entity | entities]) do
    col = _rand_range(2, cave_width - 3)
    row = _rand_range(2, cave_height - 3)

    if map[{row, col}] == ?. do # make sure to put the entity on an empty space
      _replace_tile_at(drunkards_walk, col, row, entity)
      |> _add_entities(entities)
    else
      _add_entities(drunkards_walk, entities)
    end
  end

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1

  # coveralls-ignore-start
  defp _puts_map_debugging(%{debug: false}), do: nil # nothing to do here
  defp _puts_map_debugging(%{facing: facing, current_coords: current_coords, map: map} = drunkards_walk) do
    char = case facing do
      {1,0} -> ?6
      {0, 1} -> ?2
      {-1, 0} -> ?4
      {0, -1} -> ?8
      {1, 1} -> ?3
      {1, -1} -> ?3
      {-1, 1} -> ?1
      {-1, -1} -> ?7
      _ -> ?x
    end

    spaces = drunkards_walk.cave_height * drunkards_walk.cave_width

    map_with_pointer = Map.put(map, current_coords, char)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_pointer, drunkards_walk.cave_width)
    IO.puts "spaces: #{spaces}, floors needed: #{drunkards_walk.floor_needed}"
    :timer.sleep 10
  end
  # coveralls-ignore-stop
end

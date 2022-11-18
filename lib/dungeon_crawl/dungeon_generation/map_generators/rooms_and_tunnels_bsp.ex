defmodule DungeonCrawl.DungeonGeneration.MapGenerators.RoomsAndTunnelsBsp do
  @partition_min_height  5
  @partition_min_width   7

  @cave_height     40
  @cave_width      80

  @doors           '+\''
  @wall            ?#
  @corridor_floor  ?,
  @floor           ?.
  @rock            ?\s
  @stairs_up       ?▟

  @rock_or_wall      '# '
  @floor_or_corridor '.,'

  @debug_horiz     ?-
  @debug_vert      ?|

  defstruct map: %{},
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            container: nil,
            debug: false

  defmodule Container do
    defstruct top_left_col: nil,
              top_left_row: nil,
              bottom_right_col: nil,
              bottom_right_row: nil,
              children: nil
  end

  alias DungeonCrawl.DungeonGeneration.Entities
  alias DungeonCrawl.DungeonGeneration.MapGenerators.RoomsAndTunnelsBsp
  alias DungeonCrawl.DungeonGeneration.MapGenerators.RoomsAndTunnelsBsp.Container

  @doc """
  Generates a level using the binary space partition method.

  Returns a Map containing a {row, col} tuple and a value. The value will be one of several
  single character codes indicating what is at that coordinate.

  ?\s - Rock
  ?.  - Floor
  ?#  - Wall
  ?'  - Open door
  ?+  - Closed door
  ?@  - Statue (or player location)
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, solo_level \\ nil, debug \\ false) do
    map = Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
            Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
              Map.put map, {row, col}, @rock
            end)
          end)

    container = %Container{top_left_row: 0,
                           top_left_col: 0,
                           bottom_right_row: cave_height - 1,
                           bottom_right_col: cave_width - 1}

    rooms_and_tunnels = %RoomsAndTunnelsBsp{map: map,
                                            solo_level: solo_level,
                                            container: _partition(container, 0),
                                            cave_width: cave_width,
                                            cave_height: cave_height,
                                            debug: debug}

    _puts_map_debugging(rooms_and_tunnels, rooms_and_tunnels.container)

    map =
    _tunnel_midpoints(rooms_and_tunnels)
    |> _place_rooms()
    |> _annex_adjacent_corridors()
    |> _wallify()
    |> _place_doors()
    |> _stairs_up()
    |> _convert_corridor_floors()
    |> Map.fetch!(:map)

    # for console debugging purposes only
    if debug, do: IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map, cave_width)
    map
  end

  defp _partition(%Container{top_left_col: tlc,
                             top_left_row: tlr,
                             bottom_right_col: brc,
                             bottom_right_row: brr} = container,
                  depth) do

    {mid_row, mid_col} = {_rand_range(tlr + @partition_min_height, brr - @partition_min_height),
                          _rand_range(tlc + @partition_min_width, brc - @partition_min_width)}

    child_containers =
    cond do
      _rand_range(1,5) < depth && depth > 0 -> # stop splitting regardless
        {nil, nil}
      mid_row && (mid_col == nil || _rand_range(0,1) == 1) -> # split along the horizontal
        {
          %Container{ top_left_row: tlr, top_left_col: tlc, bottom_right_row: mid_row, bottom_right_col: brc },
          %Container{ top_left_row: mid_row, top_left_col: tlc, bottom_right_row: brr, bottom_right_col: brc }
        }
      mid_col -> # split along the vertical
        {
          %Container{ top_left_row: tlr, top_left_col: tlc, bottom_right_row: brr, bottom_right_col: mid_col },
          %Container{ top_left_row: tlr, top_left_col: mid_col, bottom_right_row: brr, bottom_right_col: brc }
        }
      true -> # cannot split
        {nil, nil}
    end

    children = _partition(child_containers, depth + 1)

    %{ container | children: children }
  end

  defp _partition({%Container{} = c1, %Container{} = c2}, d), do: { _partition(c1, d), _partition(c2, d) }
  defp _partition({nil, nil}, _), do: nil

  defp _tunnel_midpoints(%RoomsAndTunnelsBsp{container: container} = rooms_and_tunnels) do
    _tunnel_midpoints(rooms_and_tunnels, container)
  end

  defp _tunnel_midpoints(rooms_and_tunnels, %Container{children: nil}), do: rooms_and_tunnels
  defp _tunnel_midpoints(%{map: map} = rooms_and_tunnels,
                         %Container{children: {child_1, child_2}}) do
    {mr1, mc1} = {
      _midpoint(child_1.top_left_row, child_1.bottom_right_row),
      _midpoint(child_1.top_left_col, child_1.bottom_right_col)
    }

    {mr2, mc2} = {
      _midpoint(child_2.top_left_row, child_2.bottom_right_row),
      _midpoint(child_2.top_left_col, child_2.bottom_right_col)
    }

    corridor_coords = for col <- Enum.to_list(mc1..mc2), row <- Enum.to_list(mr1..mr2), do: {row, col}

    map_tunneled =
      Enum.reduce(corridor_coords, map, fn(coord, map) ->
        Map.put map, coord, @corridor_floor
      end)

    %{ rooms_and_tunnels | map: map_tunneled }
    |> _puts_map_debugging(:tunnels)
    |> _tunnel_midpoints(child_1)
    |> _tunnel_midpoints(child_2)
  end

  defp _midpoint(low, high), do: round((high - low)/2) + low

  defp _place_rooms(%RoomsAndTunnelsBsp{container: container} = rooms_and_tunnels) do
    _place_rooms(rooms_and_tunnels, container)
  end
  defp _place_rooms(rooms_and_tunnels, nil), do: rooms_and_tunnels
  defp _place_rooms(%{map: map} = rooms_and_tunnels,
                    %Container{top_left_col: tlc,
                               top_left_row: tlr,
                               bottom_right_col: brc,
                               bottom_right_row: brr,
                               children: nil} = container) do
    if _rand_range(0,10) == 0 do
      rooms_and_tunnels
    else
      width = _rand_range(@partition_min_width,  abs(tlc - brc)) - 2
      height = _rand_range(@partition_min_height, abs(tlr - brr)) - 2

      rtlc = _rand_range(1, brc - tlc - width - 1) + tlc # bottom right column
      rtlr = _rand_range(1, brr - tlr - height - 1) + tlr # bottom right row

      rbrc = rtlc + width
      rbrr = rtlr + height

      room_coords = for col <- Enum.to_list(rtlc..rbrc), row <- Enum.to_list(rtlr..rbrr), do: {row, col}

      map_roomed =
        Enum.reduce(room_coords, map, fn(coord, map) ->
          Map.put map, coord, @floor
        end)

      room_corners = %{top_left_row: rtlr, top_left_col: rtlc, bottom_right_row: rbrr, bottom_right_col: rbrc}

      %{ rooms_and_tunnels | map: map_roomed }
      |> _maybe_extend_close_corridor(room_corners, container)
      |> _wallify(room_corners)
      |> _add_entities(room_corners)
      |> _puts_map_debugging(:rooms)
    end
  end
  defp _place_rooms(rooms_and_tunnels,
                    %Container{children: {child_1, child_2}}) do
    _place_rooms(rooms_and_tunnels, child_1)
    |> _place_rooms(child_2)
  end

  defp _maybe_extend_close_corridor(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels,
                                    corner_coords,
                                    %Container{top_left_col: tlc,
                                               top_left_row: tlr,
                                               bottom_right_col: brc,
                                               bottom_right_row: brr}) do
    edge_coords = List.flatten(_outer_border_coords(corner_coords))
    if Enum.any?(edge_coords, fn coord -> map[coord] == ?, end) do
      rooms_and_tunnels
    else
      corridor_coord = { _midpoint(tlr, brr), _midpoint(tlc, brc) }
      _extend_corridor(rooms_and_tunnels, corridor_coord, corner_coords)
    end
  end

  defp _extend_corridor(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels,
                        {cor_row, cor_col},
                        %{top_left_row: rtlr,
                          top_left_col: rtlc,
                          bottom_right_row: rbrr,
                          bottom_right_col: rbrc} = corner_coords) do
    cond do
      cor_row < rtlr || cor_row > rbrr ->
        next_cor_row = _one_step_towards(cor_row, rtlr)
        %{ rooms_and_tunnels |
          map: _replace_tile_at(map, cor_col, next_cor_row, @corridor_floor)}
        |> _puts_map_debugging(:extending_corridor)
        |> _extend_corridor({next_cor_row, cor_col}, corner_coords)

      cor_col < rtlc || cor_col > rbrc ->
        next_cor_col = _one_step_towards(cor_col, rtlc)
        %{ rooms_and_tunnels |
          map: _replace_tile_at(map, next_cor_col, cor_row, @corridor_floor)}
        |> _puts_map_debugging(:extending_corridor)
        |> _extend_corridor({cor_row, next_cor_col}, corner_coords)

      true ->
        rooms_and_tunnels
    end
  end

  defp _one_step_towards(start, destination) do
    # make sure that the increment is one AND and integer
    start + floor((destination - start) / abs(destination - start))
  end

  defp _annex_adjacent_corridors(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels) do
    map =
    Map.keys(map)
    |> Enum.reduce([], fn({row, col}, to_annex) ->
                          if map[{row, col}] == @corridor_floor && _should_be_annexed(map, row, col),
                            do: [{row, col} | to_annex],
                            else: to_annex
                        end)
    |> Enum.reduce(map, fn({row, col}, map) ->
      _replace_tile_at(map, col, row, @floor)
    end)


    %{ rooms_and_tunnels | map: map }
    |> _puts_map_debugging(:annex)
  end

  defp _should_be_annexed(map, row, col) do
    not(Enum.member?(@rock_or_wall, map[{row+1, col}]) &&
          Enum.member?(@rock_or_wall, map[{row-1, col}]) ||
        Enum.member?(@rock_or_wall, map[{row, col+1}]) &&
          Enum.member?(@rock_or_wall, map[{row, col-1}])) &&
      _any_neighbor(map, row, col, @floor)
  end

  defp _any_neighbor(map, row, col, char) do
    map[{row+1, col}] == char ||
      map[{row-1, col}] == char ||
      map[{row, col+1}] == char ||
      map[{row, col-1}] == char
  end

  defp _wallify(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels) do
    map =
      Map.keys(map)
      |> Enum.reduce(map, fn({row, col}, map) ->
        if map[{row, col}] == @rock && _should_be_a_wall(map, row, col),
           do: _replace_tile_at(map, col, row, @wall),
           else: map
      end)

    %{ rooms_and_tunnels | map: map }
    |> _puts_map_debugging(:wallify)
  end

  defp _wallify(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels,
                corner_coords) do
    map =
      _outer_border_coords(corner_coords)
      |> Enum.reduce(map, fn edge_coords, map ->
        _wallify_edge(map, edge_coords)
      end)

    %{ rooms_and_tunnels | map: map }
  end

  defp _wallify_edge(map, edge_line_coords) do
    edge_line_coords
    |> Enum.reduce(%{}, fn({row, col}, updates) ->
      if map[{row, col}] == @rock && _should_be_a_wall(map, row, col),
        do: Map.put(updates, {row, col}, @wall),
        else: Map.put(updates, {row, col}, map[{row, col}])
      end)
    |> _maybe_connect_to_adjacent_room(map)
    |> Enum.reduce(map, fn({coord, tile}, map) -> Map.put(map, coord, tile) end)
  end

  defp _maybe_connect_to_adjacent_room(edge_tiles, map) do
    _extra_door_eligible_segments(edge_tiles, map)
    |> Enum.reduce(edge_tiles, fn segment, door_coords ->
         if _rand_range(1, 1) == 1 do
           {coords, _} = Enum.random(segment)
           Map.put(door_coords, coords, Enum.random(@doors))
         else
           door_coords
         end
       end)
  end

  # This function detects which wall tiles are adjacent, and should be considered
  # separate segments. The goal is to limit one door per corridor and adjoining room.
  # The current room could have a corridor attached, as well as be adjacent to one or
  # more rooms along that wall, the corridor will turn into a door, and there is a chance
  # each attached room may have one but no more than one door connecting directly
  # to this room.
  defp _extra_door_eligible_segments(edge_tiles, map) do
    Enum.reduce(edge_tiles, %{0 => [], chain: 0}, fn({{row, col}, tile}, %{chain: chain} = acc) ->
      cond do
        _floor_or_corridor_on_both_sides(map, row, col) ->
          Map.put(acc, chain, [ {{row, col}, tile} | acc[chain] ])
        acc[chain] == [] ->
          acc
        true ->
          Map.put(acc, :chain, chain+1)
          |> Map.put(chain+1, [])
      end
    end)
    |> Map.delete(:chain)
    # wall segments have been computed, discard any chains that are not all stone or wall
    |> Enum.map(fn {_, chained_edge_tiles} -> chained_edge_tiles end)
    |> Enum.filter(fn chained_edge_tiles ->
         chained_edge_tiles != [] &&
           Enum.all?(chained_edge_tiles, fn {_, tile} -> Enum.member?(@rock_or_wall, tile) end)
       end)
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
      |> Enum.filter(fn char -> char == @floor end)

    neighbors != []
  end

  defp _floor_or_corridor_on_both_sides(map, row, col) do
    Enum.member?(@floor_or_corridor, map[{row+1, col}]) &&
      Enum.member?(@floor_or_corridor, map[{row-1, col}]) ||
    Enum.member?(@floor_or_corridor, map[{row, col+1}]) &&
      Enum.member?(@floor_or_corridor, map[{row, col-1}])
  end

  defp _place_doors(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels) do
    map =
      Map.keys(map)
      |> Enum.reduce(map, fn({row, col}, map) ->
        if Enum.member?([@floor, @corridor_floor], map[{row, col}]) && _should_be_door(map, row, col),
           do: _replace_tile_at(map, col, row, Enum.random(@doors)),
           else: map
      end)

    %{ rooms_and_tunnels | map: map }
    |> _puts_map_debugging(:doors)
  end

  defp _should_be_door(map, row, col) do
    (map[{row+1, col}] == @wall && map[{row-1, col}] == @wall ||
        map[{row, col+1}] == @wall && map[{row, col-1}] == @wall) &&
      _any_neighbor(map, row, col, @floor)
  end

  defp _convert_corridor_floors(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels) do
    map =
      Map.keys(map)
      |> Enum.reduce(map, fn({row, col}, map) ->
        if map[{row, col}] == @corridor_floor,
           do: _replace_tile_at(map, col, row, @floor),
           else: map
      end)

    %{ rooms_and_tunnels | map: map }
    |> _puts_map_debugging(:corridors_to_floors)
  end

  defp _stairs_up(%RoomsAndTunnelsBsp{solo_level: nil} = rooms_and_tunnels), do: rooms_and_tunnels
  defp _stairs_up(%RoomsAndTunnelsBsp{map: map,
                                      cave_height: cave_height,
                                      cave_width: cave_width} = rooms_and_tunnels) do
    row = _rand_range(0, cave_height-1)
    col = _rand_range(0, cave_width-1)

    if _valid_stair_placement(map, row, col) do
      _replace_tile_at(rooms_and_tunnels, col, row, @stairs_up)
    else
      _stairs_up(rooms_and_tunnels)
    end
  end

  defp _valid_stair_placement(map, row, col) do
    map[{row, col}] == @floor && _valid_stair_neighbors(map, row, col)
  end

  defp _valid_stair_neighbors(map, row, col) do
    adjacent_doors =
      [ map[{row+1, col}],
        map[{row-1, col}],
        map[{row, col+1}],
        map[{row, col-1}] ]
      |> Enum.filter(fn char -> Enum.member?(@doors, char) end)

    adjacent_doors == []
  end

  defp _tile_at(map, col, row) do
    map[{row, col}]
  end

  defp _replace_tile_at(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels, col, row, new_tile) do
    %{ rooms_and_tunnels | map: Map.put(map, {row, col}, new_tile) }
  end
  defp _replace_tile_at(map, col, row, new_tile) do
    Map.put(map, {row, col}, new_tile)
  end

  defp _add_entities(%RoomsAndTunnelsBsp{solo_level: nil} = rooms_and_tunnels, _) do
    rooms_and_tunnels
  end
  defp _add_entities(%RoomsAndTunnelsBsp{solo_level: solo_level} = rooms_and_tunnels,
                      %{top_left_row: tlr, top_left_col: tlc, bottom_right_row: brr, bottom_right_col: brc} = coords) do
    case :rand.uniform(100) do
      x when x > 99 -> # 1% chance this is a treasure room
        _treasure_room(rooms_and_tunnels, coords)

      x  when x > 79 -> # 20% chance empty
        rooms_and_tunnels

      _ ->
        spaces = (brc - tlc) * (brr - tlr)

        max_entities = Enum.min [solo_level, round(spaces * 0.75)]
        min_entities = Enum.min [round(solo_level / 3) + 1, max_entities]
        entities = Entities.randomize(_rand_range(min_entities, max_entities))

        _add_entities(rooms_and_tunnels, coords, entities)

    end
  end
  defp _add_entities(%RoomsAndTunnelsBsp{} = rooms_and_tunnels, _coords, []), do: rooms_and_tunnels
  defp _add_entities(%RoomsAndTunnelsBsp{map: map} = rooms_and_tunnels,
                     %{top_left_row: tlr, top_left_col: tlc, bottom_right_row: brr, bottom_right_col: brc} = coords,
                     [entity | entities]) do
    col = _rand_range(tlc, brc)
    row = _rand_range(tlr, brr)

    if map[{row, col}] == @floor do # make sure to put the entity on an empty space
      _replace_tile_at(rooms_and_tunnels, col, row, entity)
      |> _add_entities(coords, entities)
    else
      _add_entities(rooms_and_tunnels, coords, entities)
    end
  end

  def _treasure_room(%RoomsAndTunnelsBsp{} = rooms_and_tunnels,
                      %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}) do
    coords = for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col}
    _fill_room(rooms_and_tunnels, coords, Entities.treasures)
  end

  defp _fill_room(%RoomsAndTunnelsBsp{} = rooms_and_tunnels, [], _entities), do: rooms_and_tunnels
  defp _fill_room(%RoomsAndTunnelsBsp{} = rooms_and_tunnels, [{row, col} | coords], entities) do
    if _tile_at(rooms_and_tunnels.map, col, row) == @floor do
      _fill_room(_replace_tile_at(rooms_and_tunnels, col, row, Enum.random(entities)), coords, entities)
    else
      _fill_room(rooms_and_tunnels, coords, entities)
    end
  end

  defp _rand_range(min, max) when max >= min, do: :rand.uniform(max - min + 1) + min - 1
  defp _rand_range(_min, _max), do: nil

  defp _outer_border_coords(%{top_left_row: tlr,
                              top_left_col: tlc,
                              bottom_right_row: brr,
                              bottom_right_col: brc}) do
    [
      for(row <- Enum.to_list(tlr-1..brr+1), do: {row, tlc-1}),
      for(row <- Enum.to_list(tlr-1..brr+1), do: {row, brc+1}),
      for(col <- Enum.to_list(tlc..brc), do: {tlr-1, col}),
      for(col <- Enum.to_list(tlc..brc), do: {brr+1, col})
    ]
  end

  # coveralls-ignore-start
  defp _puts_map_debugging(%{debug: false} = r_t, _), do: r_t # nothing to do here
  defp _puts_map_debugging(%{map: map, cave_width: cave_width} = r_t, type)
       when is_atom(type) do
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map, cave_width)
    IO.puts "#{type}"
    :timer.sleep 200
    r_t
  end
  defp _puts_map_debugging(%{map: map, cave_width: cave_width},
                           %Container{} = container) do
    map_with_partitions = _markup_container_boundaries(map, container)

    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_partitions, cave_width)
    IO.puts "Partitions"
    :timer.sleep 500
    map_with_partitions
  end

  defp _markup_container_boundaries(map, nil), do: map
  defp _markup_container_boundaries(map,
                                    %Container{top_left_col: tlc,
                                               top_left_row: tlr,
                                               bottom_right_col: brc,
                                               bottom_right_row: brr,
                                               children: children}) do

    vert_div_coords = for row <- Enum.to_list(tlr..brr), do: {row, brc}
    horiz_div_coords = for col <- Enum.to_list(tlc..brc), do: {brr, col}

    map_with_vertical_dividers =
      Enum.reduce(vert_div_coords, map, fn(coord, map) ->
        Map.put map, coord, @debug_vert
      end)
    map_with_dividers =
      Enum.reduce(horiz_div_coords, map_with_vertical_dividers, fn(coord, map) ->
        Map.put map, coord, @debug_horiz
      end)

    case children do
      {child_1, child_2} ->
        _markup_container_boundaries(map_with_dividers, child_1)
        |> _markup_container_boundaries(child_2)

      _ ->
        map_with_dividers
    end
  end

  # coveralls-ignore-stop
end

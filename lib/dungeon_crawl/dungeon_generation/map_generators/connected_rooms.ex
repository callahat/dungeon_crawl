defmodule DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRooms do
  @room_min_height  3
  @room_max_height  9
  @room_min_width   5
  @room_max_width  15
  @iterations    1000

  @cave_height     40
  @cave_width      80

  @doors           '+\''

  defstruct map: %{},
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            iterations: 0

  alias DungeonCrawl.DungeonGeneration.Entities
  alias DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRooms

  @doc """
  Generates a level using the box method.

  Returns a Map containing a {row, col} tuple and a value. The value will be one of several
  single character codes indicating what is at that coordinate.

  ?\s - Rock
  ?.  - Floor
  ?#  - Wall
  ?'  - Open door
  ?+  - Closed door
  ?@  - Statue (or player location)
  """
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, solo_level \\ nil) do
    map = Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
            Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
              Map.put map, {row, col}, ?\s
            end)
          end)

    connected_rooms = %ConnectedRooms{map: map,
                                      cave_height: cave_height,
                                      cave_width: cave_width,
                                      solo_level: solo_level,
                                      iterations: round(cave_height * cave_width / 3) + @iterations}

    {:good_room, coords} = _try_generating_room_coordinates(connected_rooms)
    connected_rooms = _plop_room(connected_rooms, coords, ?@)

    _generate(connected_rooms)
    |> _replace_corners
    |> _stairs_up()
    |> Map.fetch!(:map)
  end

  defp _generate(%ConnectedRooms{iterations: 0} = connected_rooms), do: connected_rooms
  defp _generate(%ConnectedRooms{iterations: n} = connected_rooms) do
    case _try_generating_room_coordinates(connected_rooms) do
      {:good_room, coords} ->
        _plop_room(%{ connected_rooms | iterations: n - 1 }, coords)
        |> _generate()
      {:bad_room} ->
        _generate(%{ connected_rooms | iterations: n - 1 })
    end
  end

  def _try_generating_room_coordinates(%ConnectedRooms{map: map, cave_width: cave_width, cave_height: cave_height}) do
    w = _rand_range(@room_min_width,  @room_max_width)
    h = _rand_range(@room_min_height, @room_max_height)

    # -2 for the outer walls
    top_left_col = _rand_range(0, (cave_width  - 2) - w)
    top_left_row = _rand_range(0, (cave_height - 2) - h)

    bottom_right_col = top_left_col + w + 1
    bottom_right_row = top_left_row + h + 1

    if(Enum.any?(
              for(col <- top_left_col..bottom_right_col, do:
                for(row <- top_left_row..bottom_right_row, do:
                  _tile_at(map, col, row) == ?.
              )) |> Enum.concat,
              fn floor_tile -> floor_tile end
       )) do
      {:bad_room}
    else
      {:good_room, %{top_left_col: top_left_col, top_left_row: top_left_row, bottom_right_col: bottom_right_col, bottom_right_row: bottom_right_row}}
    end
  end

  defp _stairs_up(%ConnectedRooms{map: map,
                                  cave_height: cave_height,
                                  cave_width: cave_width,
                                  solo_level: solo_level} = connected_rooms) when is_integer(solo_level) do
    row = _rand_range(0, cave_height-1)
    col = _rand_range(0, cave_width-1)

    if _valid_stair_placement(map, row, col) do
      _replace_tile_at(connected_rooms, col, row, ?▟)
    else
      _stairs_up(connected_rooms)
    end
  end

  defp _stairs_up(connected_rooms), do: connected_rooms

  defp _valid_stair_placement(map, row, col) do
    map[{row, col}] == ?. && _valid_stair_neighbors(map, row, col)
  end

  defp _valid_stair_neighbors(map, row, col) do
    adjacent_doors =
      [ map[{row+1, col}],
        map[{row-1, col}],
        map[{row, col+1}],
        map[{row, col-1}] ]
      |> Enum.filter(fn char -> char == ?' || char == ?+ end)

    adjacent_doors == []
  end

  defp _tile_at(map, col, row) do
    map[{row, col}]
  end

  defp _replace_tile_at(%ConnectedRooms{map: map} = connected_rooms, col, row, new_tile) do
    # IO.puts "#{col} #{row} #{[new_tile]}"
    %{ connected_rooms | map: Map.put(map, {row, col}, new_tile) }
  end
  defp _replace_tile_at(map, col, row, new_tile) do
    Map.put(map, {row, col}, new_tile)
  end

  defp _replace_corners(%ConnectedRooms{map: map} = connected_rooms) do
    %{ connected_rooms | map: _replace_corners(map, Map.keys(map)) }
  end
  defp _replace_corners(map, []), do: map
  defp _replace_corners(map, [head | tail]) do
    if((map[head] == 0), do: Map.put(map, head, ?#), else: map)
    |> _replace_corners(tail)
  end

  defp _add_door(%ConnectedRooms{} = connected_rooms, {col, row}) do
    _replace_tile_at(connected_rooms, col, row, Enum.random(@doors))
  end

  defp _add_entities(%ConnectedRooms{solo_level: solo_level} = connected_rooms, _coords) when is_nil(solo_level) do
    connected_rooms
  end
  defp _add_entities(%ConnectedRooms{map: map, solo_level: solo_level} = connected_rooms, coords) do
    room_area = (coords.top_left_col - coords.bottom_right_col) * (coords.top_left_row - coords.bottom_right_row)
    number = Enum.min [round(solo_level / 10), round(:math.sqrt(room_area))]
    entities = Entities.randomize(_rand_range(1, number + 6))
    %{ connected_rooms | map: _add_entities(map, entities, coords) }
  end
  defp _add_entities(map, [], _coords), do: map
  defp _add_entities(map, [entity | entities], coords = %{top_left_col: tlc,
                                                          top_left_row: tlr,
                                                          bottom_right_col: brc,
                                                          bottom_right_row: brr}) do
    col = _rand_range(tlc + 1, brc - 1)
    row = _rand_range(tlr + 1, brr - 1)

    if map[{row, col}] == ?. do # make sure to put the entity on an empty space
      _replace_tile_at(map, col, row, entity)
      |> _add_entities(entities, coords)
    else
      _add_entities(map, [entity | entities], coords)
    end
  end

  defp _plop_room(%ConnectedRooms{} = connected_rooms, coords, ?@) do
    _corners_walls_floors(connected_rooms, coords)
  end

  defp _plop_room(%ConnectedRooms{} = connected_rooms, coords) do
    case _door_candidates(connected_rooms, coords) do
      [] ->
        connected_rooms
      door_coords ->
        _corners_walls_floors(connected_rooms, coords)
        |> _add_door(Enum.random(door_coords))
        |> _add_entities(coords)
    end
  end

  defp _corners_walls_floors(%ConnectedRooms{} = connected_rooms, _coords = %{top_left_col: tlc,
                                                                              top_left_row: tlr,
                                                                              bottom_right_col: brc,
                                                                              bottom_right_row: brr}) do
    inner_tlr = tlr + 1
    inner_brr = brr - 1
    inner_tlc = tlc + 1
    inner_brc = brc - 1
    _corners(connected_rooms, [{tlc,tlr}, {tlc, brr}, {brc, tlr}, {brc, brr}])
    |> _walls({tlc, brc}, Enum.to_list(inner_tlr..inner_brr))
    |> _walls(Enum.to_list(inner_tlc..inner_brc), {tlr, brr})
    |> _floors(Enum.to_list(inner_tlc..inner_brc), Enum.to_list(inner_tlr..inner_brr))
  end

  defp _corners(%ConnectedRooms{} = connected_rooms, []), do: connected_rooms
  defp _corners(%ConnectedRooms{} = connected_rooms, [{col, row} | corner_coords]) do
    _replace_tile_at(connected_rooms, col, row, 0)
    |> _corners(corner_coords)
  end

  defp _walls(%ConnectedRooms{} = connected_rooms, cols, {trow, brow}) when is_list(cols) do
    _walls(connected_rooms, cols, trow)
    |> _walls(cols, brow)
  end
  defp _walls(%ConnectedRooms{} = connected_rooms, {lcol, rcol}, rows) when is_list(rows) do
    _walls(connected_rooms, lcol, rows)
    |> _walls(rcol, rows)
  end
  defp _walls(%ConnectedRooms{} = connected_rooms, _col, []), do: connected_rooms
  defp _walls(%ConnectedRooms{} = connected_rooms, [], _row), do: connected_rooms
  defp _walls(%ConnectedRooms{} = connected_rooms, col, [row | rows]) do
    _replace_tile_at(connected_rooms, col, row, ?#)
    |> _walls(col, rows)
  end
  defp _walls(connected_rooms, [col | cols], row) do
    _replace_tile_at(connected_rooms, col, row, ?#)
    |> _walls(cols, row)
  end

  defp _floors(%ConnectedRooms{} = connected_rooms, [], []), do: connected_rooms
  defp _floors(%ConnectedRooms{} = connected_rooms, _c, []), do: connected_rooms
  defp _floors(%ConnectedRooms{} = connected_rooms, [], _r), do: connected_rooms
  defp _floors(%ConnectedRooms{} = connected_rooms, [col | cols], rows) do
    _floors(connected_rooms, col, rows)
    |> _floors(cols, rows)
  end
  defp _floors(%ConnectedRooms{} = connected_rooms, col, [row | rows]) do
    _replace_tile_at(connected_rooms, col, row, ?.)
    |> _floors(col, rows)
  end

  defp _door_candidates(%ConnectedRooms{} = connected_rooms, _coords = %{top_left_col: tlc,
                                                                         top_left_row: tlr,
                                                                         bottom_right_col: brc,
                                                                         bottom_right_row: brr}) do
    for [cols,rows] <- [ [[tlc, brc], Enum.to_list((tlr+1)..(brr-1))], [Enum.to_list((tlc+1)..(brc-1)), [tlr,brr]] ] do
      for col <- cols do
        for row <- rows do
          {col, row}
        end
      end
    end
    |> Enum.concat
    |> Enum.concat
    |> Enum.filter(fn({col, row}) -> _tile_at(connected_rooms.map, col, row) == ?# end)
  end

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1
end

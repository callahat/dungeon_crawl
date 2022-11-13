defmodule DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRooms do
  @room_min_height  3
  @room_max_height  9
  @room_min_width   5
  @room_max_width  15
  @iterations    1000

  @cave_height     40
  @cave_width      80

  @doors           '+\''
  @corner          ?%
  @wall            ?#
  @floor           ?.
  @rock            ?\s
  @player          ?@
  @stairs_up       ?▟

  @debug_ok        ??
  @debug_bad       ?x

  defstruct map: %{},
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            iterations: 0,
            room_coords: [],
            debug: false

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
  def generate(cave_height \\ @cave_height, cave_width \\ @cave_width, solo_level \\ nil, debug \\ false) do
    map = Enum.to_list(0..cave_height-1) |> Enum.reduce(%{}, fn(row, map) ->
            Enum.to_list(0..cave_width-1) |> Enum.reduce(map, fn(col, map) ->
              Map.put map, {row, col}, @rock
            end)
          end)

    connected_rooms = %ConnectedRooms{map: map,
                                      cave_height: cave_height,
                                      cave_width: cave_width,
                                      solo_level: solo_level,
                                      iterations: round(cave_height * cave_width / 3) + @iterations,
                                      debug: debug}

    {:good_room, coords} = _try_generating_room_coordinates(connected_rooms)
    connected_rooms = _plop_room(connected_rooms, coords, @player)

    map =
    _generate(connected_rooms)
    |> _replace_corners
    |> _stairs_up
    |> _add_entities
    |> Map.fetch!(:map)

    # for console debugging purposes only
    if debug, do: IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify(map, cave_width)
    map
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

  def _try_generating_room_coordinates(%ConnectedRooms{map: map, cave_width: cave_width, cave_height: cave_height} = cr) do
    w = _rand_range(@room_min_width,  @room_max_width)
    h = _rand_range(@room_min_height, @room_max_height)

    # -2 for the outer walls
    top_left_col = _rand_range(0, (cave_width  - 2) - w)
    top_left_row = _rand_range(0, (cave_height - 2) - h)

    bottom_right_col = top_left_col + w + 1
    bottom_right_row = top_left_row + h + 1

    _puts_map_debugging(cr,
      %{top_left_col: top_left_col,
        top_left_row: top_left_row,
        bottom_right_col: bottom_right_col,
        bottom_right_row: bottom_right_row})

    if(Enum.any?(for(col <- top_left_col..bottom_right_col, row <- top_left_row..bottom_right_row, do: {row, col}),
                 fn {row, col} -> _tile_at(map, col, row) == @floor end )) do
      {:bad_room}
    else
      {:good_room, %{top_left_col: top_left_col,
                     top_left_row: top_left_row,
                     bottom_right_col: bottom_right_col,
                     bottom_right_row: bottom_right_row}}
    end
  end

  defp _stairs_up(%ConnectedRooms{solo_level: nil} = connected_rooms), do: connected_rooms
  defp _stairs_up(%ConnectedRooms{map: map,
                                  cave_height: cave_height,
                                  cave_width: cave_width} = connected_rooms) do
    row = _rand_range(0, cave_height-1)
    col = _rand_range(0, cave_width-1)

    if _valid_stair_placement(map, row, col) do
      _replace_tile_at(connected_rooms, col, row, @stairs_up)
    else
      _stairs_up(connected_rooms)
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

  defp _replace_tile_at(%ConnectedRooms{map: map} = connected_rooms, col, row, new_tile) do
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
    if((map[head] == @corner), do: Map.put(map, head, @wall), else: map)
    |> _replace_corners(tail)
  end

  defp _add_door(%ConnectedRooms{} = connected_rooms, {col, row}) do
    _replace_tile_at(connected_rooms, col, row, Enum.random(@doors))
  end

  defp _add_entities(%ConnectedRooms{solo_level: nil} = connected_rooms) do
    connected_rooms
  end
  defp _add_entities(%ConnectedRooms{solo_level: solo_level, room_coords: room_coords} = connected_rooms) do
    max_entities = Enum.min [solo_level * 2 + 14, length(room_coords) * 11]
    min_entities = Enum.min [solo_level + 5, max_entities]
    entities = Entities.randomize(_rand_range(min_entities, max_entities))

    # 5% chance this map has a treasure room
    if :rand.uniform(100) <= 5 do
      [ treasure_room_coords | other_room_coords ] = room_coords

      %{ connected_rooms | room_coords: other_room_coords }
      |> _treasure_room(treasure_room_coords)
      |> _add_entities(entities)
    else
      _add_entities(connected_rooms, entities)
    end
  end
  defp _add_entities(%ConnectedRooms{} = connected_rooms, []), do: connected_rooms
  defp _add_entities(%ConnectedRooms{map: map, room_coords: room_coords} = connected_rooms, [entity | entities]) do
    %{top_left_col: tlc,
      top_left_row: tlr,
      bottom_right_col: brc,
      bottom_right_row: brr} = Enum.random(room_coords)

    col = _rand_range(tlc + 1, brc - 1)
    row = _rand_range(tlr + 1, brr - 1)

    if map[{row, col}] == @floor do # make sure to put the entity on an empty space
      _replace_tile_at(connected_rooms, col, row, entity)
      |> _add_entities(entities)
    else
      _add_entities(connected_rooms, entities)
    end
  end

  defp _plop_room(%ConnectedRooms{} = connected_rooms, coords, @player) do
    _corners_walls_floors(connected_rooms, coords)
  end

  defp _plop_room(%ConnectedRooms{} = connected_rooms, coords) do
    case _door_candidates(connected_rooms, coords) do
      [] ->
        connected_rooms
      door_coords ->
        _corners_walls_floors(connected_rooms, coords)
        |> _add_door(Enum.random(door_coords))
        |> _puts_map_debugging(:plop)
    end
  end

  defp _corners_walls_floors(%ConnectedRooms{} = connected_rooms, coords = %{top_left_col: tlc,
                                                                             top_left_row: tlr,
                                                                             bottom_right_col: brc,
                                                                             bottom_right_row: brr}) do
    inner_tlr = tlr + 1
    inner_brr = brr - 1
    inner_tlc = tlc + 1
    inner_brc = brc - 1

    room_coords = for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col}
    floor_coords = for col <- Enum.to_list(inner_tlc..inner_brc), row <- Enum.to_list(inner_tlr..inner_brr), do: {row, col}
    corner_coords = [{tlr, tlc}, {brr, tlc}, {tlr, brc}, {brr, brc}]
    wall_coords = room_coords -- (floor_coords ++ corner_coords)

    _corners(connected_rooms, corner_coords)
    |> _walls(wall_coords)
    |> _floors(floor_coords)
    |> Map.put(:room_coords, [ coords | connected_rooms.room_coords ])
  end

  defp _corners(%ConnectedRooms{} = connected_rooms, []), do: connected_rooms
  defp _corners(%ConnectedRooms{} = connected_rooms, [{row, col} | corner_coords]) do
    _replace_tile_at(connected_rooms, col, row, @corner)
    |> _corners(corner_coords)
  end

  defp _walls(%ConnectedRooms{} = connected_rooms, []), do: connected_rooms
  defp _walls(%ConnectedRooms{} = connected_rooms, [ {row, col} | wall_coords]) do
    _replace_tile_at(connected_rooms, col, row, @wall)
    |> _walls(wall_coords)
  end

  defp _floors(%ConnectedRooms{} = connected_rooms, []), do: connected_rooms
  defp _floors(%ConnectedRooms{} = connected_rooms, [{row, col} | floor_coords]) do
    _replace_tile_at(connected_rooms, col, row, @floor)
    |> _floors(floor_coords)
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
    |> Enum.filter(fn({col, row}) -> _tile_at(connected_rooms.map, col, row) == @wall end)
  end

  def _treasure_room(%ConnectedRooms{} = connected_rooms, %{top_left_col: tlc,
                                                            top_left_row: tlr,
                                                            bottom_right_col: brc,
                                                            bottom_right_row: brr}) do
    inner_tlr = tlr + 1
    inner_brr = brr - 1
    inner_tlc = tlc + 1
    inner_brc = brc - 1

    coords = for col <- Enum.to_list(inner_tlc..inner_brc), row <- Enum.to_list(inner_tlr..inner_brr), do: {row, col}
    _fill_room(connected_rooms, coords, Entities.treasures)
  end

  defp _fill_room(%ConnectedRooms{} = connected_rooms, [], _entities), do: connected_rooms
  defp _fill_room(%ConnectedRooms{} = connected_rooms, [{row, col} | coords], entities) do
    if _tile_at(connected_rooms.map, col, row) == @floor do
      _fill_room(_replace_tile_at(connected_rooms, col, row, Enum.random(entities)), coords, entities)
    else
      _fill_room(connected_rooms, coords, entities)
    end
  end

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1

  # coveralls-ignore-start
  defp _puts_map_debugging(_connected_rooms, _ops)
  defp _puts_map_debugging(%{debug: false} = connected_rooms, :plop), do: connected_rooms
  defp _puts_map_debugging(%{debug: false}, _), do: nil # nothing to do here
  defp _puts_map_debugging(%{map: map, cave_width: cave_width, iterations: iterations},
         %{top_left_col: tlc,
           top_left_row: tlr,
           bottom_right_col: brc,
           bottom_right_row: brr}) when iterations > 850 do

    inner_tlr = tlr + 1
    inner_brr = brr - 1
    inner_tlc = tlc + 1
    inner_brc = brc - 1

    floor_coords = for col <- Enum.to_list(inner_tlc..inner_brc), row <- Enum.to_list(inner_tlr..inner_brr), do: {row, col}

    map_with_room_attempt = Enum.reduce(floor_coords, map, fn({row, col}, map) ->
                              char = if _tile_at(map, col, row) == @rock, do: @debug_ok, else: @debug_bad
                              Map.put map, {row, col}, char
                            end)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_room_attempt, cave_width)
    IO.puts "iterations left: #{iterations}"
    :timer.sleep 100
  end
  defp _puts_map_debugging(%{map: map, cave_width: cave_width, iterations: iterations} = cr, :plop) do
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map, cave_width)
    IO.puts "iterations left: #{iterations}"
    :timer.sleep 500
    cr
  end
  defp _puts_map_debugging(_, _), do: nil # ignore the puts debug statement
  # coveralls-ignore-stop
end

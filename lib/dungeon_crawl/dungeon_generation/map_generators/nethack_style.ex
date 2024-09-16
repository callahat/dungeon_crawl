defmodule DungeonCrawl.DungeonGeneration.MapGenerators.NethackStyle do
  @room_min_height  4 # inclusive of walls
  @room_max_height 11
  @room_min_width   4
  @room_max_width  17

  @cave_height     40
  @cave_width      80

  @doors           ~c"+'"
  @wall            ?#
  @corridor_floor  ?,
  @floor           ?.
  @rock            ?\s
  @stairs_up       ?▟

  @rock_or_wall      ~c"# "
  @floor_or_corridor ~c".,"

  @debug_horiz     ?-
  @debug_vert      ?|
  @debug_ok        ??
  @debug_bad       ?x


  defstruct map: %{},
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            iterations: 100,
            rectangles: [],
            room_coords: [],
            debug: false

  defmodule Rectangle do
    defstruct top_left_col: nil,
              top_left_row: nil,
              bottom_right_col: nil,
              bottom_right_row: nil
  end

  alias DungeonCrawl.DungeonGeneration.Entities
  alias DungeonCrawl.DungeonGeneration.MapGenerators.NethackStyle
  alias DungeonCrawl.DungeonGeneration.MapGenerators.NethackStyle.Rectangle

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

    rectangle = %Rectangle{top_left_row: 0,
                           top_left_col: 0,
                           bottom_right_row: cave_height - 1,
                           bottom_right_col: cave_width - 1}

    nethack_style = %NethackStyle{map: map,
                                  solo_level: solo_level,
                                  cave_width: cave_width,
                                  cave_height: cave_height,
                                  rectangles: [rectangle],
                                  debug: debug}

    nethack_style = _generate(nethack_style)
                    |> _puts_map_debugging()

#    map =
#    _tunnel_midpoints(rooms_and_tunnels)
#    |> _place_rooms()
#    |> _annex_adjacent_corridors()
#    |> _wallify()
#    |> _place_doors()
#    |> _stairs_up()
#    |> _convert_corridor_floors()
#    |> Map.fetch!(:map)
#
#    # for console debugging purposes only
#    if debug, do: IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map, cave_width)
    map
  end

  defp _generate(%NethackStyle{iterations: 0} = nethack_style), do: nethack_style
  defp _generate(%NethackStyle{rectangles: []} = nethack_style), do: nethack_style
  defp _generate(%NethackStyle{rectangles: rectangles, iterations: i} = nethack_style) do
    {[rectangle], rectangles} = rectangles |> Enum.shuffle |> Enum.split(1)

    _generate(%{nethack_style | iterations: i - 1}, rectangle, 20)
  end

  defp _generate(%NethackStyle{} = nethack_style, rectangle, 0), do: nethack_style
  defp _generate(%NethackStyle{} = nethack_style, rectangle, tries) do
    case _try_generating_room_coordinates(nethack_style, rectangle) do
      {:good_room, coords} ->
        _plop_room(nethack_style, coords)
        |> _update_available_rectangles(rectangle, coords)
        |> _generate()
      {:bad_room} ->
        _generate(nethack_style, rectangle, tries - 1)
    end
  end

  def _try_generating_room_coordinates(%NethackStyle{map: map} = ns, rectangle) do
    max_width = Enum.min([@room_max_width, rectangle.bottom_right_col - rectangle.top_left_col])
    max_height = Enum.min([@room_max_height, rectangle.bottom_right_row - rectangle.top_left_row])

    w = _rand_range(@room_min_width,  max_width)
    h = _rand_range(@room_min_height, max_height)

    # -2 for the outer walls
    top_left_col = _rand_range(rectangle.top_left_col, rectangle.bottom_right_col - w)
    top_left_row = _rand_range(rectangle.top_left_row, rectangle.bottom_right_row - h)

    bottom_right_col = top_left_col + w
    bottom_right_row = top_left_row + h

    _puts_map_debugging(ns,
      %{top_left_col: top_left_col,
        top_left_row: top_left_row,
        bottom_right_col: bottom_right_col,
        bottom_right_row: bottom_right_row})

    if(bottom_right_col > rectangle.bottom_right_col ||
       bottom_right_row > rectangle.bottom_right_row) do
      {:bad_room}
    else
      {:good_room, %{top_left_col: top_left_col,
        top_left_row: top_left_row,
        bottom_right_col: bottom_right_col,
        bottom_right_row: bottom_right_row}}
    end
  end

  defp _plop_room(%NethackStyle{} = nethack_style, coords) do
    _walls_floors(nethack_style, coords)
    |> _puts_map_debugging()
  end

  defp _walls_floors(%NethackStyle{} = nethack_style, coords = %{top_left_col: tlc,
    top_left_row: tlr,
    bottom_right_col: brc,
    bottom_right_row: brr}) do

    room_coords = for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col}
    floor_coords = for col <- Enum.to_list((tlc + 1)..(brc - 1)),
                       row <- Enum.to_list((tlr + 1)..(brr - 1)),
                       do: {row, col}
    wall_coords = room_coords -- floor_coords

    _walls(nethack_style, wall_coords)
    |> _floors(floor_coords)
    |> Map.put(:room_coords, [ coords | nethack_style.room_coords ])
  end

  defp _walls(%NethackStyle{} = nethack_style, []), do: nethack_style
  defp _walls(%NethackStyle{} = nethack_style, [ {row, col} | wall_coords]) do
    _replace_tile_at(nethack_style, col, row, @wall)
    |> _walls(wall_coords)
  end

  defp _floors(%NethackStyle{} = nethack_style, []), do: nethack_style
  defp _floors(%NethackStyle{} = nethack_style, [{row, col} | floor_coords]) do
    _replace_tile_at(nethack_style, col, row, @floor)
    |> _floors(floor_coords)
  end

  defp _update_available_rectangles(%NethackStyle{rectangles: rectangles} = nethack_style, rectangle, coords) do
    %{ nethack_style | rectangles: Enum.reject(rectangles, fn r -> r == rectangle end) ++
                                   _split(rectangle, coords, nethack_style)}
  end

  defp _split(%Rectangle{top_left_col: otlc,
                         top_left_row: otlr,
                         bottom_right_col: obrc,
                         bottom_right_row: obrr} = _rectangle,
             %{top_left_col: itlc,
               top_left_row: itlr,
               bottom_right_col: ibrc,
               bottom_right_row: ibrr} = _inner_coords,
             nethack_style) do
    # the outer rectangle contains up to nine rectangles, assuming a rectangle
    # can have null dimensions.
    # Start with a 4x4 grid generated from the rectangle coordinates
    row_coords = [otlr, itlr, ibrr, obrr]
    col_coords = [otlc, itlc, ibrc, obrc]
    rows = length(row_coords)
    cols = length(col_coords)
    coords = for row <- row_coords, col <- col_coords do {col, row} end

    # Calculate 9 coordinate pairs; this is essentially getting a 3x3 for the top left coords,
    # then shifting it to get the bottom right coords using the list
    rectangles = \
    for row <- 0..(rows-2), col <- 1..(cols-1) do
      {tlc, tlr} = Enum.at(coords, row*rows + col - 1)
      {brc, brr} = Enum.at(coords, (row + 1) * cols + col)
      %Rectangle{top_left_col: tlc,
        top_left_row: tlr,
        bottom_right_col: brc,
        bottom_right_row: brr}
    end
    |> Enum.slide(4, 0) # The inner rectangle is at position 5, slide it to the
    |> Enum.slice(1, 8) # front and remove it
    |> _reduce_rectangles(nethack_style)
    |> Enum.reject(&_invalid_rectangle_size?/1)

    rectangles
  end

  defp _reduce_rectangles([], _), do: []
  defp _reduce_rectangles([rectangle | rectangles], %{cave_height: h, cave_width: w} = nh) do
    %Rectangle{top_left_col: tlc,
      top_left_row: tlr,
      bottom_right_col: brc,
      bottom_right_row: brr} = rectangle
    tlc = if tlc == 0, do: tlc, else: tlc + 1
    tlr = if tlr == 0, do: tlr, else: tlr + 1
    brc = if brc == w - 1, do: brc, else: brc - 1
    brr = if brr == h - 1, do: brr, else: brr - 1

    [
      %Rectangle{top_left_col: tlc,
        top_left_row: tlr,
        bottom_right_col: brc,
        bottom_right_row: brr}
      | _reduce_rectangles(rectangles, nh)
    ]
  end

  defp _invalid_rectangle_size?(%Rectangle{top_left_col: tlc,
                                           top_left_row: tlr,
                                           bottom_right_col: brc,
                                           bottom_right_row: brr}) do
    height = brr - tlr
    width = brc - tlc

    height < @room_min_height || width < @room_min_width
  end
  
  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1

  defp _tile_at(map, col, row) do
    map[{row, col}]
  end

  defp _replace_tile_at(%NethackStyle{map: map} = nethack_style, col, row, new_tile) do
    %{ nethack_style | map: Map.put(map, {row, col}, new_tile) }
  end
  defp _replace_tile_at(map, col, row, new_tile) do
    Map.put(map, {row, col}, new_tile)
  end

  # coveralls-ignore-start
  defp _puts_map_debugging(%{debug: false} = nethack_style), do: nethack_style
  defp _puts_map_debugging(%{map: map, cave_width: cave_width, rectangles: rectangles} = nh) do
    map_with_rectangles = _map_with_rectangles(rectangles, nh, nil)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_rectangles, cave_width)
    IO.puts "rectangles left: #{length(rectangles)}"
    :timer.sleep 250
    nh
  end
  defp _puts_map_debugging(%{debug: false} = nethack_style, _), do: nethack_style
  defp _puts_map_debugging(%{map: map, cave_width: cave_width, iterations: iterations, rectangles: rectangles} = nh,
         %{top_left_col: tlc,
           top_left_row: tlr,
           bottom_right_col: brc,
           bottom_right_row: brr}) do

    floor_coords = for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col}

    map_with_room_attempt = Enum.reduce(floor_coords, map, fn({row, col}, map) ->
      char = if _tile_at(map, col, row) == @rock, do: @debug_ok, else: @debug_bad
      Map.put map, {row, col}, char
    end)
    map_with_room_attempt = _map_with_rectangles(rectangles, nh, nil)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_room_attempt, cave_width)
    IO.puts "iterations left: #{iterations}, rectangles left: #{length rectangles}"
    :timer.sleep 250
    nh
  end
  defp _puts_map_debugging(nh, :full), do: nh # temporar
  defp _puts_map_debugging(_, _), do: nil # ignore the puts debug statement

  defp _map_with_rectangles(rectangles, %NethackStyle{map: map}, conflict_char \\ @debug_bad) do
    rectangles
    |> Enum.with_index(fn %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}, i ->
      for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col, 48 + Integer.mod(i, 10)}
    end)
    |> Enum.reduce(map, fn floor_coords, map_acc ->
      Enum.reduce(floor_coords, map_acc, fn({row, col, char}, map_acc) ->
        char = _map_with_rectangles_char(_tile_at(map_acc, col, row), char, conflict_char)
        Map.put map_acc, {row, col}, char
      end)
    end)
  end
  defp _map_with_rectangles_char(tile, char, nil) do
    if tile == @rock, do: char, else: tile
  end
  defp _map_with_rectangles_char(tile, char, conflict_char) do
    if tile == @rock, do: char, else: conflict_char
  end
  # coveralls-ignore-stop
end

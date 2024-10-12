defmodule DungeonCrawl.DungeonGeneration.MapGenerators.NethackStyle do
  @room_min_height  4 # inclusive of walls
  @room_max_height 11
  @room_min_width   4
  @room_max_width  17

  @cave_height     40
  @cave_width      80

  @doors           ~c"+'s"
  @random_door     ~c"+'"
  @closed_door     ?+
  @secret_door     ?s
  @wall            ?#
  @corridor_floor  ?,
  @floor           ?.
  @rock            ?\s
  @stairs_up       ?▟

  @corridor_or_rock  ~c" ,"

  @debug_ok        ??
  @debug_bad       ?x


  defstruct map: %{},
            cave_height: nil,
            cave_width: nil,
            solo_level: nil,
            iterations: 100,
            rectangles: [],
            room_coords: [],
            connected_rooms: %{},
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
                    |> _resize_touching_rooms()
                    |> _puts_map_debugging()
                    |> _sort_room_coords()
                    |> _puts_map_debugging(:sorted)
                    |> _make_corridors()
                    |> _corridors_to_floors()
                    |> _add_closets()
#                    |> _mineralize()
                    |> _stairs_up()
                    |> _add_entities()
                    |> _puts_map_debugging()

#    IO.inspect nethack_style.room_coords
#    IO.inspect nethack_style.room_coords |> Enum.sort

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
    nethack_style.map
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
        |> Map.put(:room_coords, [ coords | nethack_style.room_coords ])
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

  defp _invalid_rectangle_size?(%{top_left_col: tlc,
                                  top_left_row: tlr,
                                  bottom_right_col: brc,
                                  bottom_right_row: brr}) do
    height = brr - tlr
    width = brc - tlc

    height < @room_min_height || width < @room_min_width
  end

  defp _resize_touching_rooms(%NethackStyle{map: map, room_coords: room_coords} = nh) do
    _resize_touching_rooms(%{ nh | room_coords: [] }, room_coords)
    |> _puts_map_debugging()
  end
  defp _resize_touching_rooms(nethack_style, []), do: nethack_style
  defp _resize_touching_rooms(
         %NethackStyle{map: map, cave_height: h, cave_width: w} = nethack_style,
         [room_coord | room_coords]) do
    %{top_left_col: tlc,
      top_left_row: tlr,
      bottom_right_col: brc,
      bottom_right_row: brr} = room_coord

    dtlc = tlc - 1
    dtlr = tlr - 1
    dbrc = brc + 1
    dbrr = brr + 1

    new_room_coord = \
    [
      { {1,0,0,0}, dtlc..dbrc, dtlr..dtlr }, # top row
      { {0,1,0,0}, dtlc..dbrc, dbrr..dbrr }, # bottom row
      { {0,0,1,0}, dtlc..dtlc, dtlr..dbrr }, # left column
      { {0,0,0,1}, dbrc..dbrc, dtlr..dbrr }, # right column
    ]
    |> _check_adjacent(room_coord, nethack_style)
    |> _maybe_shrink_room_on_map(room_coord, nethack_style)
    |> _resize_touching_rooms(room_coords)

  end
  defp _check_adjacent([], room_coord, _nethack_style), do: room_coord
  defp _check_adjacent([{ scalar, col_range, row_range} | adjacent], room_coord, %{map: map} = nh) do
    adj_coords = for(col <- Enum.to_list(col_range),
                     row <- Enum.to_list(row_range),
                     do: {row, col})
                 |> Enum.reject( fn {row, col} ->
                       row < 0 || col < 0 || row > nh.cave_height - 1 || col > nh.cave_width - 1
                     end)
    _puts_map_debugging(nh, adj_coords, :check_adjacent)

    if Enum.any?(adj_coords, fn {row, col} ->
                                tile = _tile_at(map, col, row)
                                tile && tile != @rock
                              end) do
      _check_adjacent(adjacent, _shrink_room_coord(scalar, room_coord), nh)
    else
      _check_adjacent(adjacent, room_coord, nh)
    end
  end

  defp _shrink_room_coord(
         {trd, brd, lcd, rcd},
         %{top_left_col: tlc,
           top_left_row: tlr,
           bottom_right_col: brc,
           bottom_right_row: brr}) do
    %{top_left_col: tlc + lcd,
      top_left_row: tlr + trd,
      bottom_right_col: brc - rcd,
      bottom_right_row: brr - brd}
  end

  defp _maybe_shrink_room_on_map(new, original, %NethackStyle{} = nethack_style) when original == new do
    %{ nethack_style | room_coords: [ original | nethack_style.room_coords ] }
  end
  defp _maybe_shrink_room_on_map(
         %{top_left_col: ntlc, top_left_row: ntlr, bottom_right_col: nbrc, bottom_right_row: nbrr} = new,
         %{top_left_col: otlc, top_left_row: otlr, bottom_right_col: obrc, bottom_right_row: obrr} = old,
         %NethackStyle{} = nethack_style) do

    old_room_coords = for col <- Enum.to_list(otlc..obrc), row <- Enum.to_list(otlr..obrr), do: {row, col}

    if _rand_range(1,3) == 3 || _invalid_rectangle_size?(new) do
      # 33% chance we just remove the room even if it has valid dimensions
      _rocks(nethack_style, old_room_coords)
    else
      room_coords = for col <- Enum.to_list(ntlc..nbrc), row <- Enum.to_list(ntlr..nbrr), do: {row, col}
      floor_coords = for col <- Enum.to_list((ntlc + 1)..(nbrc - 1)),
                         row <- Enum.to_list((ntlr + 1)..(nbrr - 1)),
                         do: {row, col}

      wall_coords = room_coords -- floor_coords
      rock_coords = old_room_coords -- room_coords

      _walls(nethack_style, wall_coords)
      |> _rocks(rock_coords)
      |> Map.put(:room_coords, [ new | nethack_style.room_coords ])
    end
  end

  defp _rocks(%NethackStyle{} = nethack_style, []), do: nethack_style
  defp _rocks(%NethackStyle{} = nethack_style, [ {row, col} | rock_coords]) do
    _replace_tile_at(nethack_style, col, row, @rock)
    |> _rocks(rock_coords)
  end

  defp _sort_room_coords(%NethackStyle{room_coords: coords, connected_rooms: cr, cave_width: cw} = nethack_style) do
    connected_rooms = for(i <- Enum.to_list(0..length(coords)-1), do: {i, i})
                      |> Enum.into(%{})
    %{ nethack_style |
      room_coords: Enum.sort_by(coords, fn a -> {a.top_left_row, a.top_left_col} end),
      connected_rooms: connected_rooms}
  end

  # corridors
  defp _make_corridors(%NethackStyle{room_coords: coords} = nethack_style) when length(coords) < 2,
       do: nethack_style
  defp _make_corridors(%NethackStyle{room_coords: coords, connected_rooms: cr} = nethack_style) do
    # put current door, then if making the corridor is successful, put the target door, otherwise
    # the corridor will dead end.
    nethack_style
    |> _make_corridors_first_pass(Map.size(cr) - 1)
    |> _make_corridors_second_pass(Map.size(cr) - 2)
    |> _make_corridors_third_pass()
  end
  defp _make_corridors_first_pass(nethack_style, offset) when offset < 1, do: nethack_style
  defp _make_corridors_first_pass(%{room_coords: coords, connected_rooms: cr} = nethack_style, offset) do
    next_offset = if :rand.uniform(50) == 1, do: 0, else: offset - 1

    _join(offset, offset - 1, nethack_style)
    |> _make_corridors_first_pass(next_offset)
  end
  defp _make_corridors_second_pass(nethack_style, offset) when offset < 2, do: nethack_style
  defp _make_corridors_second_pass(%{room_coords: coords, connected_rooms: cr} = nethack_style, offset) do
    _join(offset, offset - 2, nethack_style)
    |> _make_corridors_second_pass(offset - 1)
  end
  defp _make_corridors_third_pass(%{room_coords: coords, connected_rooms: cr} = nethack_style) do
    unconnected_room_pair = \
    for(a <- 0..(Map.size(cr) - 1), b <- 0..(Map.size(cr) - 1), do: {a, b})
    |> Enum.find(fn {a, b} ->
      Map.fetch(cr, a) != Map.fetch(cr, b)
    end)

    if unconnected_room_pair do
      {a, b} = unconnected_room_pair
      _join(a, b, nethack_style)
    else
      nethack_style
    end
  end

  defp _commit_corridor(corridor, map) do
    door_type = if :rand.uniform(5) == 1, do: [@secret_door], else: @random_door
    map_with_doors = Enum.reduce(
      [corridor.starting_door_coord,
        corridor.target_door_coord], map, fn({row, col}, map) ->
        Map.put map, {row, col}, Enum.random(door_type)
      end)
    Enum.reduce(corridor.coords, map_with_doors, fn({row, col}, map) ->
      Map.put map, {row, col}, ?,
    end)
  end

  defp _join(current_room_index, target_room_index, %{room_coords: coords, connected_rooms: cr} = nh) do
    if Map.fetch(cr, current_room_index) == Map.fetch(cr,target_room_index) do
      nh
    else
      room_number = Enum.min([Map.get(cr, target_room_index), Map.get(cr, current_room_index)])

      connected_rooms = %{ cr | target_room_index => room_number, current_room_index => room_number}
      _join(connected_rooms, Enum.at(coords, target_room_index), Enum.at(coords, current_room_index), nh)
    end
  end

  defp _join(updated_connected_rooms,
         %{top_left_col: ctlc, top_left_row: ctlr, bottom_right_col: cbrc, bottom_right_row: cbrr},
         %{top_left_col: ttlc, top_left_row: ttlr, bottom_right_col: tbrc, bottom_right_row: tbrr},
         %{room_coords: coords, connected_rooms: cr, map: map} = nethack_style) do
    # It might be better to collect candidate walls, as rooms could be left and up,
    # and a left and a bottom wall could connect, when the left and right might be too
    # close but far above and below and not have a good path.
    corridor_details = \
    cond do
      # target room is to the right of current room
      ttlc > cbrc ->
        %{drow: 0,
          dcol: 1,
          starting_door_coord: _door_coord(map, cbrc, ctlr+1, cbrc, cbrr-1),
          target_door_coord: _door_coord(map, ttlc, ttlr+1, ttlc, tbrr-1)}
      # target room is below current room
      ttlr > cbrr ->
        %{drow: 1,
          dcol: 0,
          starting_door_coord: _door_coord(map, ctlc+1, cbrr, cbrc-1, cbrr),
          target_door_coord: _door_coord(map, ttlc+1, ttlr, tbrc-1, ttlr)}
      # target room is to the left of current room
      tbrc < ctlc ->
        %{drow: 0,
          dcol: -1,
          starting_door_coord: _door_coord(map, ctlc, ctlr+1, ctlc, cbrr-1),
          target_door_coord: _door_coord(map, tbrc, ttlr+1, tbrc, tbrr-1)}
      # target must be above current room
      true ->
        %{drow: -1,
          dcol: 0,
          starting_door_coord: _door_coord(map, ctlc+1, ctlr, cbrc-1, ctlr),
          target_door_coord: _door_coord(map, ttlc+1, tbrr, tbrc-1, tbrr)}
    end

    case _start_digging(nethack_style, corridor_details) do
      {:done, corridor_details} ->
        %{ nethack_style |
          map: _commit_corridor(corridor_details, map),
          connected_rooms: updated_connected_rooms }

      _ ->
        nethack_style
    end
  end

  defp _door_coord(map, tlc, tlr, brc, brr) do
    row = _rand_range(tlr, brr)
    col = _rand_range(tlc, brc)

    if _ok_door(map, row, col) do
      {row, col}
    else
      [&_ok_door/3,
        fn map, row, col -> Enum.member?(@doors, _tile_at(map, col, row)) end]
      |> Enum.reduce(nil, fn func,acc ->
        acc || Enum.find(for(r <- tlr..brr, c <- tlc..brc, do: {r,c}), fn {r,c} -> func.(map, c, r) end)
      end)
    end
  end

  defp _ok_door(map, row, col) do
    _tile_at(map, col, row) == @wall && !_by_door(map, row, col)
  end

  defp _by_door(map, row, col) do
    [{1,0}, {-1,0}, {0,1}, {0,-1}]
    |> Enum.any?(fn {dr, dc} -> Enum.member?(@doors, _tile_at(map, col + dc, row + dr)) end)
  end

  # A starting and target door will never start on the same square, they will always be at least one
  # square away at this point. Start the corridor a square away from the starting door. Add that coordinate
  # to the current corridor coords, calculate the next.
  defp _start_digging(_, %{starting_door_coord: s, target_door_coord: t} = corridor_details)
       when is_nil(s) or is_nil(t), do: {:failed, corridor_details}
  defp _start_digging(%NethackStyle{} = nh, corridor_details) do
    %{drow: dr,
      dcol: dc,
      starting_door_coord: {cr, cc},
      target_door_coord: {tr, tc}
    } = corridor_details

    corridor_details = \
      Map.merge(corridor_details, %{current_coord: {cr+dr, cc+dc}, target_coord: {tr-dr, tc-dc}, coords: []})
    _dig_corridor(nh, corridor_details, 500)
  end

  defp _dig_corridor(_nh, corridor_details, 0), do: {:failed, corridor_details}
  defp _dig_corridor(_nh, %{current_coord: current, target_coord: target} = corridor_details, _cnt)
       when current == target do
    {:done, %{ corridor_details | coords: Enum.uniq([target | corridor_details.coords])}}
  end

  defp _dig_corridor(
         %{cave_height: height, cave_width: width, map: map} = nh,
         %{drow: dr, dcol: dc, current_coord: {cr, cc}, target_coord: {tr, tc}} = corridor_details,
         cnt) do

    cond do
      cr < 0 || cc < 0 || tr < 0 || tc < 0 ||
        cr > height - 1 || cc > width - 1 || tr > height - 1 || tc > width - 1 ->
           {:failed, corridor_details}

       Enum.member?(@corridor_or_rock, _tile_at(map, cc, cr)) ->
        # if rock or existing corridor, can corridor here
        corridor_details = %{ corridor_details | coords: [{cr, cc} | corridor_details.coords] }
                           |> _next_delta_and_coord(nh)

        _puts_map_debugging(nh, corridor_details,  :corridor_planning)

        _dig_corridor(nh, corridor_details, cnt - 1)

      true ->
        {:failed, corridor_details}
    end
  end

  defp _next_delta_and_coord(
         %{drow: dr, dcol: dc, current_coord: {cr, cc}, target_coord: {tr, tc}} = corridor_details,
         %{map: map} = nh
       ) do
    row_index = abs(tr - cr)
    col_index = abs(tc - cc)

    # The further in one vector the target is, the less likely the short vector will
    # be chosen as the prefereable direction, but theres still a chance
    {row_index, col_index} = \
    cond do
      row_index > col_index && :rand.uniform(row_index - col_index + 1) == 1 ->
        {0, col_index}
      col_index > row_index && :rand.uniform(col_index - row_index + 1) == 1 ->
        {row_index, 0}
      true ->
        {row_index, col_index}
    end

    {drow, dcol} = \
    cond do
      # shall direction be changed?
      dr && col_index > row_index ->
        ddc = if cc > tc, do: -1, else: 1
        if _ok_corridor_coord(map, cc + ddc, cr, corridor_details),
           do: {0, ddc},
           else: {dr, dc}
      dc && row_index > col_index ->
        ddr = if cr > tr, do: -1, else: 1
        if _ok_corridor_coord(map, cc, cr + ddr, corridor_details),
           do: {ddr, 0},
           else: {dr, dc}

      # can continue in current direction?
      _ok_corridor_coord(map, cc + dc, cr + dr, corridor_details) ->
        {dr, dc}

      # try to change direction anyway as current direction is blocked
      true ->
        {dr, dc} = cond do
          dr -> if cc > tc, do: {0, -1}, else: {0, 1}
          true -> if cr > tr, do: {-1, 0}, else: {1, 0}
        end
        if _ok_corridor_coord(map, cc + dc, cr + dr, corridor_details),
           do: {dr, dc},
           else: {-dr, -dc}
    end

    %{ corridor_details | drow: drow, dcol: dcol, current_coord: {cr + drow, cc + dcol}}
  end

  defp _ok_corridor_coord(map, col, row, %{coords: coords}) do
    Enum.member?(@corridor_or_rock, _tile_at(map, col, row)) &&
      (!Enum.member?(coords, {row, col}) || :rand.uniform(10) == 1)
  end

  defp _corridors_to_floors(%NethackStyle{map: map} = nethack_style) do
    map =
      Map.keys(map)
      |> Enum.reduce(map, fn({row, col}, map) ->
        if map[{row, col}] == @corridor_floor,
           do: _replace_tile_at(map, col, row, @floor),
           else: map
      end)

    %{ nethack_style | map: map }
    |> _puts_map_debugging()
  end

  defp _add_closets(%NethackStyle{room_coords: coords} = nethack_style) do
    closets = _rand_range(0, trunc(length(coords) / 2) + 1)

    _add_closets(nethack_style, closets)
  end

  defp _add_closets(%NethackStyle{} = nethack_style, 0), do: nethack_style
  defp _add_closets(%NethackStyle{room_coords: coords} = nethack_style, count) do
    %{top_left_col: tlc,
      top_left_row: tlr,
      bottom_right_col: brc,
      bottom_right_row: brr} = Enum.random(coords)

    wall_coords = for(r <- (tlr + 1)..(brr - 1), do: [{0, -1, r, tlc}, {0, 1, r, brc}]) ++
                  for(c <- (tlc + 1)..(brc - 1), do: [{-1, 0, tlr, c}, {1, 0, brr, c}])
                  |> Enum.flat_map(&(&1))
                  |> Enum.shuffle()
                  |> Enum.take(8)

    # try to add a closet up to  times
    _add_closet(wall_coords, nethack_style)
    |> _add_closets(count - 1)
  end

  defp _add_closet([], %NethackStyle{} = nethack_style), do: nethack_style
  defp _add_closet([{drow, dcol, row, col} | wall_coords], %NethackStyle{map: map} = nethack_style) do
    _puts_map_debugging(nethack_style, {row, col}, {row + drow, col + dcol}, :check_closet)
    if _ok_door(map, row, col) && _ok_closet(map, row + drow, col + dcol) do
      map = _replace_tile_at(map, col, row, @closed_door)
            |> _replace_tile_at(col + dcol, row + drow, @floor)
      %{ nethack_style | map: map }
    else
      _add_closet(wall_coords, nethack_style)
    end
  end

  defp _ok_closet(map, row, col) do
    _tile_at(map, col, row) == @rock &&
    [_tile_at(map, col - 1, row),
     _tile_at(map, col + 1, row),
     _tile_at(map, col, row - 1),
     _tile_at(map, col, row + 1)]
    |> Enum.all?(fn i -> i == @rock || i == @wall end)
  end

  # stairs
  defp _stairs_up(%NethackStyle{solo_level: nil} = nethack_style), do: nethack_style
  defp _stairs_up(%NethackStyle{
      connected_rooms: connected_rooms,
      room_coords: room_coords} = nethack_style) do
    room_groups = \
    connected_rooms
    |> Enum.reduce(%{},
       fn {room_index, connected_to}, acc ->
         room_coord = Enum.at(room_coords, room_index)
         Map.put(acc, connected_to, [ room_coord | Map.get(acc, connected_to, []) ])
       end)
    |> Enum.map(fn {_room_index, rooms} -> rooms end)

    _stairs_up(nethack_style, room_groups)
  end

  defp _stairs_up(%NethackStyle{map: map} = nethack_style, []), do: nethack_style
  defp _stairs_up(%NethackStyle{map: map} = nethack_style, [room_group | room_groups]) do
    %{top_left_col: tlc,
      top_left_row: tlr,
      bottom_right_col: brc,
      bottom_right_row: brr} = Enum.random(room_group)

    row = _rand_range(tlr+1, brr-1)
    col = _rand_range(tlc+1, brc-1)

    if _valid_stair_placement(map, row, col) do
      _replace_tile_at(nethack_style, col, row, @stairs_up)
      |> _stairs_up(room_groups)
    else
      _stairs_up(nethack_style, [room_group | room_groups])
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

  # entities

  defp _add_entities(%NethackStyle{solo_level: nil} = nethack_style) do
    nethack_style
  end
  defp _add_entities(%NethackStyle{solo_level: solo_level,
    cave_height: cave_height,
    cave_width: cave_width} = nethack_style) do
    max_entities = Enum.min [solo_level * 3, round(cave_height * cave_width * 0.15)]
    min_entities = Enum.min [solo_level + 5, max_entities]
    entities = Entities.randomize(_rand_range(min_entities, max_entities))

    nethack_style
    |> _maybe_fill_vaults()
    |> _add_entities(entities)
  end
  defp _add_entities(%NethackStyle{} = nethack_style, []), do: nethack_style
  defp _add_entities(%NethackStyle{map: map,
    cave_height: cave_height,
    cave_width: cave_width} = nethack_style,
         [entity | entities]) do
    col = _rand_range(2, cave_width - 3)
    row = _rand_range(2, cave_height - 3)

    if map[{row, col}] == ?. do # make sure to put the entity on an empty space
      _replace_tile_at(nethack_style, col, row, entity)
      |> _add_entities(entities)
    else
      _add_entities(nethack_style, entities)
    end
  end

  defp _maybe_fill_vaults(%NethackStyle{connected_rooms: connected_rooms, room_coords: rooms} = nethack_style)
    when map_size(connected_rooms) > 1 do
    lone_rooms =
      connected_rooms
      |> Enum.reduce(%{},
           fn {_, connected_to}, acc ->
             Map.put(acc, connected_to, Map.get(acc, connected_to, 0) + 1)
           end)
      |> Enum.reject(fn {_, connections} -> connections > 1 end) # it only connects to itself

    # 10% chance if we have a room that did not connect to anything else, and we had other
    # rooms, that its getting filled with loot
    if length(lone_rooms) > 0 && :rand.uniform(10) == 1 do
      {index, _} = Enum.random(lone_rooms)

      room = Enum.at(rooms, index)

      _treasure_room(nethack_style, room)
    else
      nethack_style
    end
  end
  defp _maybe_fill_vaults(%NethackStyle{} = nethack_style), do: nethack_style

  defp _treasure_room(%NethackStyle{} = nethack_style,
        %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}) do
    coords = for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col}
    _fill_room(nethack_style, coords, Entities.treasures)
  end

  defp _fill_room(%NethackStyle{} = nethack_style, [], _entities), do: nethack_style
  defp _fill_room(%NethackStyle{map: map} = nethack_style, [{row, col} | coords], entities) do
    if _tile_at(map, col, row) == @floor do
      _fill_room(_replace_tile_at(nethack_style, col, row, Enum.random(entities)), coords, entities)
    else
      _fill_room(nethack_style, coords, entities)
    end
  end

  # utility functions
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
    map_with_rectangles = _map_with_rectangles(rectangles, nh, [@rock])
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
    map_with_room_attempt = _map_with_rectangles(rectangles, nh, [@rock])
    map_with_room_attempt = Enum.reduce(floor_coords, map_with_room_attempt, fn({row, col}, map) ->
      char = if _tile_at(map, col, row) == @rock, do: @debug_ok, else: @debug_bad
      Map.put map, {row, col}, char
    end)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_room_attempt, cave_width)
    IO.puts "rectangles left: #{length rectangles}, iterations left: #{iterations}"
    :timer.sleep 250

    nh
  end
  defp _puts_map_debugging(%{map: map, cave_width: cave_width, room_coords: room_coords} = nh, :sorted) do
    map_with_numbered_rooms = _map_with_rectangles(room_coords, nh, [@rock, @floor])
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_numbered_rooms, cave_width)
    IO.puts "Numbered rooms: #{ length room_coords }"
    :timer.sleep 500

    nh
  end
  defp _puts_map_debugging(%{map: map, cave_width: cave_width} = nh, coord_list, :check_adjacent) do
    map_with_check = Enum.reduce(coord_list, map, fn({row, col}, map) ->
      char = if _tile_at(map, col, row) == @rock, do: ??, else: @debug_bad
      Map.put map, {row, col}, char
    end)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_check, cave_width)
    IO.puts "Checking for touching rooms"
    :timer.sleep 250

    nh
  end
  defp _puts_map_debugging(%{map: map, cave_width: cave_width} = nh, {dr, dc}, {cr, cc}, :check_closet) do
    map_with_check = Map.put(map, {dr, dc}, ??)
                     |> Map.put({cr, cc}, ??)
    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_check, cave_width)
    IO.puts "Checking closet placement"
    :timer.sleep 250

    nh
  end
  defp _puts_map_debugging(%{map: map, cave_width: cw} = nh, corridor_details, :corridor_planning) do
    map_with_doors = Enum.reduce(
      [corridor_details.starting_door_coord,
        corridor_details.target_door_coord], map, fn({row, col}, map) ->
      Map.put map, {row, col}, ?+
    end)
    map_with_halls = Enum.reduce(corridor_details.coords, map_with_doors, fn({row, col}, map) ->
      Map.put map, {row, col}, ?,
    end)
    dir_char = cond do
        corridor_details.drow > 0 -> ?v
        corridor_details.drow < 0 -> ?^
        corridor_details.dcol > 0 -> ?>
        corridor_details.dcol < 0 -> ?<
        true -> ?X
      end
    map_with_direction = Map.put(map_with_halls, corridor_details.current_coord, dir_char)

    IO.puts DungeonCrawl.DungeonGeneration.Utils.stringify_with_border(map_with_direction, cw)
    IO.puts "Corridor"
    :timer.sleep 100

    nh
  end
  defp _puts_map_debugging(nh, :full), do: nh # temporar
  defp _puts_map_debugging(_, _), do: nil # ignore the puts debug statement

  defp _map_with_rectangles(rectangles, %NethackStyle{map: map}, numberable \\ [@rock]) do
    rectangles
    |> Enum.with_index(fn %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}, i ->
      for col <- Enum.to_list(tlc..brc), row <- Enum.to_list(tlr..brr), do: {row, col, 48 + Integer.mod(i, 10)}
    end)
    |> Enum.reduce(map, fn floor_coords, map_acc ->
      Enum.reduce(floor_coords, map_acc, fn({row, col, char}, map_acc) ->
        char = _map_with_rectangles_char(_tile_at(map_acc, col, row), char, numberable)
        Map.put map_acc, {row, col}, char
      end)
    end)
  end
  defp _map_with_rectangles_char(tile, char, numberable) do
    if Enum.member?(numberable, tile), do: char, else: tile
  end
  # coveralls-ignore-stop
end

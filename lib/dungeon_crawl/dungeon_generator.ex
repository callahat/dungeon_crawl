defmodule DungeonCrawl.DungeonGenerator do
  @room_min_height  3
  @room_max_height  9
  @room_min_width   5
  @room_max_width  15
  @iterations    1000

  @cave_height     40
  @cave_width      80

  @doors           '+\''
  #@entities        Enum.to_list(?A..?|)
  @entities        ''

  def generate() do
    map = Enum.to_list(0..(@cave_height * @cave_width - 1)) |> Enum.reduce(%{}, fn(i, acc) -> Map.put(acc, i, ?\s) end) 
    {:good_room, coords} = try_generating_room_coordinates(map)
    map = _plop_room(map, coords, ?@)

    _generate(map, @iterations)
    |> _replace_corners
  end

  def pretty_print(map) do
    map
    |> _map_to_charlist
    |> _render
  end

  defp _generate(map, 0), do: map
  defp _generate(map, n) do
    case try_generating_room_coordinates(map) do
      {:good_room, coords} ->
        # IO.puts inspect coords
        entities = @entities |> Enum.shuffle |> Enum.take(_rand_range(1,6))
        _plop_room(map, coords, entities)
        |> _generate(n - 1)
      {:bad_room} ->
        _generate(map, n - 1)
    end
  end

  def try_generating_room_coordinates(map) do
    w = _rand_range(@room_min_width,  @room_max_width)
    h = _rand_range(@room_min_height, @room_max_height)

    # -2 for the outer walls
    top_left_col = _rand_range(0, (@cave_width  - 2) - w)
    top_left_row = _rand_range(0, (@cave_height - 2) - h)

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

  defp _rand_range(min, max), do: :rand.uniform(max - min + 1) + min - 1

  defp _tile_at(map, col, row) do
    map[row * @cave_width + col]
  end

  defp _replace_tile_at(map, col, row, new_tile) do
    # IO.puts "#{col} #{row} #{[new_tile]}"
    Map.put(map, row * @cave_width + col, new_tile)
  end

  defp _map_to_charlist(map) do
    map
    |> Map.to_list
    |> Enum.sort(fn({k1, _}, {k2, _}) -> k1 < k2 end)
    |> Enum.map(fn({_, v}) -> v end)
  end

  defp _replace_corners(map) when is_map(map), do: _replace_corners(map,Map.keys(map))
  defp _replace_corners(map, []), do: map
  defp _replace_corners(map, [head | tail]) do
    if((map[head] == 0), do: Map.put(map, head, ?#), else: map)
    |> _replace_corners(tail)
  end

  defp _add_door(map, {col, row}) do
    _replace_tile_at(map, col, row, Enum.random(@doors))
  end

  defp _add_entities(map, [], _coords), do: map
  defp _add_entities(map, [entity | entities], coords = %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}) do
    _replace_tile_at(map, _rand_range(tlc + 1, brc - 1), _rand_range(tlr + 1, brr - 1), _maybe_treasure_instead(entity))
    |> _add_entities(entities, coords)
  end

  defp _maybe_treasure_instead(entity) do
    if _rand_range(1,4) == 1 do
      ?$
    else
      entity
    end
  end

  defp _plop_room(map, coords = %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}, ?@) do
    _corners_walls_floors(map, coords)
    |> _replace_tile_at(_rand_range(tlc + 1, brc - 1), _rand_range(tlr + 1, brr - 1), ?@)
  end

  defp _plop_room(map, coords = %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}, entities) do
    case _door_candidates(map, coords) do
      [] -> 
        map
      door_coords ->
        _corners_walls_floors(map, coords)
        |> _add_door(Enum.random(door_coords))
        |> _add_entities(entities, coords)
    end
  end

  defp _corners_walls_floors(map, coords = %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}) do
    inner_tlr = tlr + 1
    inner_brr = brr - 1
    inner_tlc = tlc + 1
    inner_brc = brc - 1
    _corners(map, [{tlc,tlr}, {tlc, brr}, {brc, tlr}, {brc, brr}])
    |> _walls({tlc, brc}, Enum.to_list(inner_tlr..inner_brr))
    |> _walls(Enum.to_list(inner_tlc..inner_brc), {tlr, brr})
    |> _floors(Enum.to_list(inner_tlc..inner_brc), Enum.to_list(inner_tlr..inner_brr))
  end

  defp _corners(map, []), do: map
  defp _corners(map, [{col, row} | corner_coords]) do
    _replace_tile_at(map, col, row, 0)
    |> _corners(corner_coords)
  end

  defp _walls(map, cols, {trow, brow}) when is_list(cols) do
    _walls(map, cols, trow)
    |> _walls(cols, brow)
  end
  defp _walls(map, {lcol, rcol}, rows) when is_list(rows) do
    _walls(map, lcol, rows)
    |> _walls(rcol, rows)
  end
  defp _walls(map, _col, []), do: map
  defp _walls(map, [], _row), do: map
  defp _walls(map, col, [row | rows]) do
    _replace_tile_at(map, col, row, ?#)
    |> _walls(col, rows)
  end
  defp _walls(map, [col | cols], row) do
    _replace_tile_at(map, col, row, ?#)
    |> _walls(cols, row)
  end
  
  defp _floors(map, [], []), do: map
  defp _floors(map, _c, []), do: map
  defp _floors(map, [], _r), do: map
  defp _floors(map, [col | cols], rows) do
    _floors(map, col, rows)
    |> _floors(cols, rows)
  end
  defp _floors(map, col, [row | rows]) do
    _replace_tile_at(map, col, row, ?.)
    |> _floors(col, rows)
  end

  defp _door_candidates(map, coords = %{top_left_col: tlc, top_left_row: tlr, bottom_right_col: brc, bottom_right_row: brr}) do
    for [cols,rows] <- [ [[tlc, brc], Enum.to_list((tlr+1)..(brr-1))], [Enum.to_list((tlc+1)..(brc-1)), [tlr,brr]] ] do
      for col <- cols do
        for row <- rows do
          {col, row}
        end
      end
    end
    |> Enum.concat
    |> Enum.concat
    |> Enum.filter(fn({col, row}) -> map[row * @cave_width + col] == ?# end)
  end

  defp _replace_tiles([], map), do: map
  defp _replace_tiles([{col, row, new_tile} | tail], map), do: _replace_tiles(tail, _replace_tile_at(map, col, row, new_tile))

  defp _render(map) do
    Enum.chunk(map, @cave_width) |> Enum.map(&(to_string(&1))) |> Enum.join("\n") |> IO.puts
  end
end

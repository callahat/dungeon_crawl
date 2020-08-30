defmodule DungeonCrawl.Scripting.Shape do
  @moduledoc """
  The various functions relating to returning shapes (in terms of either coordinates or 
  map tile ids). When determining coordinates in the shape, coordinates moving out
  from the origin up to the range away are considered.

  `include_origin` may be true or false by default. This will include origin in the shape's
  coordinates that are returned.
  `bypass_blocking` will be "soft" by default. This parameter can be true, false, or "soft".
  When false, any tile that is "blocking" will end the ray from the origin, instead of allowing
  the ray reach the full length of the range. When "soft", it will behave similar to false
  except when that tile also has "soft: true", in which case the ray from origin may include
  that soft blocking tile and continue towards full distance of the range.
  """

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Runner


  @doc """
  Returns map tile ids that fall on a line from the given origin.
  """
  def line(%Runner{state: state, object_id: object_id}, direction, range, include_origin \\ false, bypass_blocking \\ "soft") do
    origin = Instances.get_map_tile_by_id(state, %{id: object_id})
    {vec_row, vec_col} = Direction.delta(direction) |> Tuple.to_list |> Enum.map(&(&1 * range)) |> List.to_tuple

    range_coords = _coords_between(state, origin, %{row: origin.row + vec_row, col: origin.col + vec_col}, bypass_blocking)

    if include_origin, do: [{origin.row, origin.col} | range_coords], else: range_coords
  end

  defp _coords_between(state, starting, ending, bypass_blocking, est \\ &round/1) do
    delta = %{row: ending.row - starting.row,
              col: ending.col - starting.col}

    steps = max(abs(delta.row), abs(delta.col))

    _coords_between(state, starting, delta, 1, steps, bypass_blocking, [], est)
    |> Enum.reverse
  end

  defp _coords_between(_state, _origin, _delta, step, steps, _bypass_blocking, coords, _est) when step > steps, do: coords
  defp _coords_between(state, origin, delta, step, steps, true, coords, est) do
    coord = _calc_coord(origin, delta, step, steps, est)
    if _outside_board(state, coord) do
      coords
    else
      _coords_between(state, origin, delta, step + 1, steps, true, [ coord | coords], est)
    end
  end
  defp _coords_between(state, origin, delta, step, steps, bypass_blocking, coords, est) do
    {row, col} = coord = _calc_coord(origin, delta, step, steps, est)
    next_map_tile = Instances.get_map_tile(state, %{row: row, col: col})
    if is_nil(next_map_tile) ||
       (next_map_tile.parsed_state[:blocking] && ! (next_map_tile.parsed_state[:soft] && bypass_blocking == "soft")) do
      coords
    else
      _coords_between(state, origin, delta, step + 1, steps, bypass_blocking, [ coord | coords], est)
    end
  end

  defp _calc_coord(origin, delta, step, steps, est) do
    {origin.row + est.(delta.row * step / steps), origin.col + est.(delta.col * step / steps)}
  end

  defp _outside_board(state, {row, col}) do
    row >= state.state_values[:rows] || row < 0 || col >= state.state_values[:cols] || col < 0
  end

  @doc """
  Returns map tile ids that form a cone emminating from the origin out to the range,
  and spanning about 45 degrees on either side of the center line.
  """
  def cone(%Runner{state: state, object_id: object_id}, direction, range, width, include_origin \\ false, bypass_blocking \\ "soft") do
    origin = Instances.get_map_tile_by_id(state, %{id: object_id})
    {d_row, d_col} = Direction.delta(direction)
    {vec_row, vec_col} =  {d_row * range, d_col * range}

    vectors = if vec_row == 0, do:   Enum.to_list(-width..width) |> Enum.map(fn row -> {row, vec_col} end),
                               else: Enum.to_list(-width..width) |> Enum.map(fn col -> {vec_row, col} end)

    range_coords = vectors
                   |> Enum.flat_map(fn {vr, vc} ->
                       _coords_between(state, origin, %{row: origin.row + vr, col: origin.col + vc}, bypass_blocking)
                      end)
                   |> Enum.uniq

    if include_origin, do: [{origin.row, origin.col} | range_coords], else: range_coords
  end

  @doc """
  Returns map tile ids that from a circle around the origin out to the range.
  Origin is included by default, and bypass blocking defaults to soft.
  """
  def circle(%Runner{state: state, object_id: object_id}, range, include_origin \\ true, bypass_blocking \\ "soft") do
    origin = Instances.get_map_tile_by_id(state, %{id: object_id})

    vectors = [{range, 0}, {-range, 0}, {0, range}, {0, -range}]
              |> _circle_rim_coordinates(%{row: 0, col: 0}, 1- range, 1, -2 * range, 0, range)

    range_coords = vectors
                   |> Enum.flat_map(fn {vr, vc} ->
                       _coords_between(state, origin, %{row: origin.row + vr, col: origin.col + vc}, bypass_blocking, &floor/1) ++
                        _coords_between(state, origin, %{row: origin.row + vr, col: origin.col + vc}, bypass_blocking, &ceil/1)
                      end)
                   |> Enum.uniq
                   |> Enum.sort

    if include_origin, do: [{origin.row, origin.col} | range_coords], else: range_coords
  end

  # using midpoint circle algorithm
  defp _circle_rim_coordinates(coords, _origin, _f, _ddf_x, _ddf_y, x, y) when x >= y, do: coords
  defp _circle_rim_coordinates(coords, origin, f, ddf_x, ddf_y, x, y) do
    {y, ddf_y, f} = if f >= 0, do: {y - 1, ddf_y + 2, f + ddf_y + 2}, else: {y, ddf_y, f}
    x = x + 1
    ddf_x = ddf_x + 2
    f = f + ddf_x

    [ {origin.col + x, origin.row + y},
      {origin.col - x, origin.row + y},
      {origin.col + x, origin.row - y},
      {origin.col - x, origin.row - y},
      {origin.col + y, origin.row + x},
      {origin.col - y, origin.row + x},
      {origin.col + y, origin.row - x},
      {origin.col - y, origin.row - x}
      | coords ]
    |> _circle_rim_coordinates(origin, f, ddf_x, ddf_y, x, y)
  end

  @doc """
  Returns map tile ids that are up to the range in steps from the origin. This will wrap around corners
  and blocking tiles as long as the number of steps to get to that coordinate is within the range.
  """
  def blob(%Runner{state: state, object_id: object_id}, range, include_origin \\ true, bypass_blocking \\ "soft") do
    origin = Instances.get_map_tile_by_id(state, %{id: object_id})

    %{row: row, col: col} = origin

    coords = if include_origin, do: [{row, col}], else: []

    _blob(state, range, bypass_blocking, coords, [{row + 1, col}, {row - 1, col}, {row, col + 1}, {row, col - 1}])
  end

  defp _blob(_state, range, _, coords, _frontier) when range <= 0, do: coords
  defp _blob(state, range, bypass_blocking, coords, frontier) do
    new_coords = frontier
                 |> Enum.filter(fn({row, col}) ->
                      candidate_tile = Instances.get_map_tile(state, %{row: row, col: col})
                      candidate_tile &&
                        (bypass_blocking == true ||
                           !candidate_tile.parsed_state[:blocking] ||
                           (candidate_tile.parsed_state[:soft] && bypass_blocking == "soft"))
                    end)
                 |> Enum.uniq
    new_frontier = new_coords
                   |> Enum.flat_map(fn({row, col}) ->
                        [{row + 1, col}, {row - 1, col}, {row, col + 1}, {row, col - 1}]
                      end)
                   |> Enum.uniq
                   |> Enum.filter(fn(coord) ->
                        ! Enum.member?(coords, coord)
                      end)
    _blob(state, range - 1, bypass_blocking, new_coords ++ coords, new_frontier)
  end
end

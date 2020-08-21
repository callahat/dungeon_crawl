defmodule DungeonCrawl.Scripting.Shape do
  @moduledoc """
  The various functions relating to returning shapes (in terms of either coordinates or 
  map tile ids).
  """

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.Scripting.Direction
  alias DungeonCrawl.Scripting.Runner


  @doc """
  Returns map tile ids that fall on a line from the given origin.
  """
  def line(%Runner{state: state, object_id: object_id}, direction, range, include_origin \\ true, bypass_blocking \\ true) do
    origin = Instances.get_map_tile_by_id(state, %{id: object_id})
    {vec_row, vec_col} = Direction.delta(direction) |> Tuple.to_list |> Enum.map(&(&1 * range)) |> List.to_tuple

    range_coords = _coords_between(state, origin, %{row: origin.row + vec_row, col: origin.col + vec_col}, bypass_blocking)

    if include_origin, do: [{origin.row, origin.col} | range_coords], else: range_coords
  end

  defp _coords_between(state, starting, ending, bypass_blocking) do
    delta = %{row: ending.row - starting.row,
              col: ending.col - starting.col}

    steps = max(abs(delta.row), abs(delta.col))

    _coords_between(state, starting, delta, 1, steps, bypass_blocking, [])
    |> Enum.reverse
  end

  defp _coords_between(_state, _origin, _delta, step, steps, _bypass_blocking, coords) when step > steps, do: coords
  defp _coords_between(state, origin, delta, step, steps, true, coords) do
    coord = _calc_coord(origin, delta, step, steps)
    if _outside_board(state, coord) do
      coords
    else
      _coords_between(state, origin, delta, step + 1, steps, true, [ coord | coords])
    end
  end
  defp _coords_between(state, origin, delta, step, steps, bypass_blocking, coords) do
    {row, col} = coord = _calc_coord(origin, delta, step, steps)
    next_map_tile = Instances.get_map_tile(state, %{row: row, col: col})
    if is_nil(next_map_tile) ||
       (next_map_tile.parsed_state[:blocking] && ! (next_map_tile.parsed_state[:soft] && bypass_blocking == "soft")) do
      coords
    else
      _coords_between(state, origin, delta, step + 1, steps, bypass_blocking, [ coord | coords])
    end
  end

  defp _calc_coord(origin, delta, step, steps) do
    {origin.row + round(delta.row * step / steps), origin.col + round(delta.col * step / steps)}
  end

  defp _outside_board(state, {row, col}) do
    row >= state.state_values[:rows] || row < 0 || col >= state.state_values[:cols] || col < 0
  end

  @doc """
  Returns map tile ids that form a cone emminating from the origin out to the range,
  and spanning about 45 degrees on either side of the center line.
  """
  def cone(%Runner{state: state, object_id: object_id}, direction, range, include_origin \\ true, bypass_blocking \\ true) do

  end
end

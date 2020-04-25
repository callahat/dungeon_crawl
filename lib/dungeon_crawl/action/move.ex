defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances.MapTile

  # todo: rename this
  def go(%MapTile{} = entity_map_tile, %MapTile{} = destination, %Instances{} = state) do
    cond do
      !entity_map_tile.parsed_state[:not_pushy] && _is_pushable(destination.parsed_state[:pushable], entity_map_tile, destination) ->
        direction = _get_direction(entity_map_tile, destination)
        pushed_location = Instances.get_map_tile(state, destination, direction)

        case go(destination, pushed_location, state) do
          # TODO: need the new_old_location_map to update all the pushed map tiles in the display
          {:ok, tile_changes, state} ->
            _move(entity_map_tile, destination, state, tile_changes)

          _ ->
            {:invalid}
        end

      destination.parsed_state[:blocking] ->
        {:invalid}

      true ->
        _move(entity_map_tile, destination, state, %{})

    end
  end
  def go(_, _, _), do: {:invalid}

  def can_move(nil), do: false
  def can_move(destination) do
    !destination.parsed_state[:blocking]
  end

  defp _move(entity_map_tile, destination, state, tile_changes) do
    top_tile = Map.take(destination, [:map_instance_id, :row, :col, :z_index])
    {new_location, state} = Instances.update_map_tile(state, entity_map_tile, Map.put(top_tile, :z_index, top_tile.z_index+1))
    old_location_top_tile = Instances.get_map_tile(state, Map.take(entity_map_tile, [:row, :col]))
    old_location = if old_location_top_tile, do: old_location_top_tile, else: Map.merge(%MapTile{}, Map.take(entity_map_tile, [:row, :col]))
    new_changes = %{ {new_location.row, new_location.col} => new_location,
                     {old_location.row, old_location.col} => old_location}
    {:ok, Map.merge(tile_changes, new_changes), state}
  end

  defp _is_pushable(pushable, entity_map_tile, destination) do
    case pushable do
      true  -> _is_pushable("nsew", entity_map_tile, destination)

      directions when is_binary(directions) ->
        directions
        |> String.split("",trim: true)
        |> Enum.any?(&_in_direction(&1, entity_map_tile, destination))

      _ -> false
    end
  end

  defp _in_direction(direction, entity_map_tile, destination) do
    {row_delta, col_delta} = {destination.row - entity_map_tile.row, destination.col - entity_map_tile.col}
    case direction do
      "n" -> row_delta < 0 # subject must be south moving north
      "s" -> row_delta > 0
      "e" -> col_delta > 0
      "w" -> col_delta < 0
      _   -> false
    end
  end

  # assumes orthogonal direction, no diagonal
  defp _get_direction(entity_map_tile, destination) do
    {row_delta, col_delta} = {destination.row - entity_map_tile.row, destination.col - entity_map_tile.col}

    cond do
      row_delta < 0 -> "north"
      row_delta > 0 -> "south"
      col_delta > 0 -> "east"
      true ->          "west" # col_delta < 0 -> "west" #this is the last valid push option; cannot push in idle direction
    end
  end
end

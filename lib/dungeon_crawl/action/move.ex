defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Scripting.Direction

  # todo: rename this
  def go(%MapTile{} = entity_map_tile, %MapTile{} = destination, %Instances{} = state, :absolute, tile_changes) do
    _move(entity_map_tile, destination, state, tile_changes)
  end
  def go(%MapTile{} = entity_map_tile, %MapTile{} = destination, %Instances{} = state) do
    cond do
      _is_teleporter(destination, entity_map_tile) ->
        Direction.coordinates_to_edge(destination, destination.parsed_state[:facing], state.state_values)
        |> _possible_teleporter_destinations(state, [], true)
        |> Enum.reverse()
        |> _teleport(entity_map_tile, state)

      _is_pushable(destination.parsed_state[:pushable], entity_map_tile, destination) ->
        direction = _get_direction(entity_map_tile, destination)
        pushed_location = Instances.get_map_tile(state, destination, direction)

        case go(destination, pushed_location, state) do
          # TODO: need the new_old_location_map to update all the pushed map tiles in the display
          {:ok, tile_changes, state} ->
            _move(entity_map_tile, destination, state, tile_changes)

          _ ->
            if destination.parsed_state[:squishable] do
              {squashed_tile, state} = Instances.delete_map_tile(state, destination)
              _move(entity_map_tile, squashed_tile, state, %{})
            else
              {:invalid}
            end
        end

      (destination.parsed_state[:blocking] || destination.parsed_state[:flying]) &&
          !(entity_map_tile.parsed_state[:flying] && destination.parsed_state[:low]) ->
        {:invalid}

      _is_squishable(destination, entity_map_tile) ->
        {_squashed_tile, state} = Instances.delete_map_tile(state, destination)
        _move(entity_map_tile, destination, state, %{})

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

  defp _is_teleporter(destination, entity_tile) do
    destination.parsed_state[:teleporter] &&
      Direction.orthogonal_direction(entity_tile, destination) == [destination.parsed_state[:facing]]
  end

  defp _is_pushable(pushable, entity_map_tile, destination) do
    if entity_map_tile.parsed_state[:not_pushing] do
      false
    else
      case pushable do
        true  -> _is_pushable("nsew", entity_map_tile, destination)

        directions when is_binary(directions) ->
          directions
          |> String.split("",trim: true)
          |> Enum.any?(&_in_direction(&1, entity_map_tile, destination))

        _ -> false
      end
    end
  end

  defp _is_squishable(destination, entity_map_tile) do
    if entity_map_tile.parsed_state[:not_squishing] do
      false
    else
      destination.parsed_state[:squishable]
    end
  end

  defp _in_direction(direction, entity_map_tile, destination) do
    #{row_delta, col_delta} = {destination.row - entity_map_tile.row, destination.col - entity_map_tile.col}
    dirs = Direction.orthogonal_direction(entity_map_tile, destination)
    case direction do
      "n" -> Enum.member?(dirs, "north") # subject must be south moving north
      "s" -> Enum.member?(dirs, "south")
      "e" -> Enum.member?(dirs, "east")
      "w" -> Enum.member?(dirs, "west")
      _   -> false
    end
  end

  # assumes orthogonal direction, no diagonal; and idle should not be obtained if we made it here.
  # there should be only one direction
  defp _get_direction(entity_map_tile, destination) do
    Direction.orthogonal_direction(entity_map_tile, destination)
    |> Enum.at(0)
  end

  defp _possible_teleporter_destinations(_, _state, _candidates, first \\ false)
  defp _possible_teleporter_destinations([], _state, candidates, _first), do: candidates
  defp _possible_teleporter_destinations([_], _state, candidates, _first), do: candidates
  defp _possible_teleporter_destinations([a, b | coordinates], state, candidates, first) do
    map_tile = Instances.get_map_tile(state, a)
    candidate_tile = Instances.get_map_tile(state, b)

    candidates = cond do
                   _is_destination_candidate(map_tile, candidate_tile, first) -> [candidate_tile | candidates]
                   true -> candidates
                 end

    if candidate_tile do
      _possible_teleporter_destinations([b | coordinates], state, candidates)
    else
      _possible_teleporter_destinations(coordinates, state, candidates)
    end
  end

  defp _is_destination_candidate(nil, _, _), do: false
  defp _is_destination_candidate(_, nil, _), do: false
  defp _is_destination_candidate(map_tile, candidate_tile, true) do
     map_tile && candidate_tile && map_tile.parsed_state[:teleporter]
  end
  defp _is_destination_candidate(map_tile, candidate_tile, false) do
    _is_teleporter(map_tile, candidate_tile)
  end

  defp _teleport([], _entity_map_tile, _state), do: {:invalid}
  defp _teleport([candidate_destination | candidates], %MapTile{} = entity_map_tile, %Instances{} = state) do
    case go(entity_map_tile, candidate_destination, state) do
      {:ok, _tile_changes, _state} = result->
        result

      _ -> # invalid for whatever reason
        _teleport(candidates, entity_map_tile, state)
    end
  end
end

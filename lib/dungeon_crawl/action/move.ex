defmodule DungeonCrawl.Action.Move do
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Scripting.Direction

  # todo: rename this
  def go(%Tile{} = entity_tile, %Tile{} = destination, %Levels{} = state, :absolute, tile_changes) do
    _move(entity_tile, destination, state, tile_changes)
  end
  def go(%Tile{} = entity_tile, %Tile{} = destination, %Levels{} = state) do
    cond do
      _is_teleporter(destination, entity_tile) ->
        Direction.coordinates_to_edge(destination, destination.parsed_state[:facing], state.state_values)
        |> _possible_teleporter_destinations(state, [], true)
        |> Enum.reverse()
        |> _teleport(entity_tile, state)

      _is_pushable(destination.parsed_state[:pushable], entity_tile, destination) ->
        direction = _get_direction(entity_tile, destination)
        pushed_location = Levels.get_tile(state, destination, direction)

        case go(destination, pushed_location, state) do
          {:ok, tile_changes, state} ->
            _move(entity_tile, destination, state, tile_changes)

          _ ->
            if destination.parsed_state[:squishable] do
              {squashed_tile, state} = Levels.delete_tile(state, destination)
              _move(entity_tile, squashed_tile, state, %{})
            else
              {:invalid}
            end
        end

      (destination.parsed_state[:blocking] || destination.parsed_state[:flying]) &&
          !(entity_tile.parsed_state[:flying] && destination.parsed_state[:low]) ->
        {:invalid}

      _is_squishable(destination, entity_tile) ->
        {_squashed_tile, state} = Levels.delete_tile(state, destination)
        _move(entity_tile, destination, state, %{})

      true ->
        _move(entity_tile, destination, state, %{})

    end
  end
  def go(_, _, _), do: {:invalid}

  def can_move(nil), do: false
  def can_move(destination) do
    !destination.parsed_state[:blocking]
  end

  defp _move(entity_tile, destination, state, tile_changes) do
    top_tile = Map.take(destination, [:level_instance_id, :row, :col, :z_index])
    {new_location, state} = Levels.update_tile(state, entity_tile, Map.put(top_tile, :z_index, top_tile.z_index+1))
    {new_location, state} = _increment_player_steps(state, new_location)

    old_location_top_tile = Levels.get_tile(state, Map.take(entity_tile, [:row, :col]))
    old_location = if old_location_top_tile, do: old_location_top_tile, else: Map.merge(%Tile{}, Map.take(entity_tile, [:row, :col]))
    new_changes = %{ {new_location.row, new_location.col} => new_location,
                     {old_location.row, old_location.col} => old_location}
    {:ok, Map.merge(tile_changes, new_changes), state}
  end

  defp _increment_player_steps(state, %{parsed_state: %{player: true}} = player_tile) do
    steps = player_tile.parsed_state[:steps] || 0
    Levels.update_tile_state(state, player_tile, %{steps: steps + 1})
  end
  defp _increment_player_steps(state, tile), do: {tile, state}

  defp _is_teleporter(destination, entity_tile) do
    destination.parsed_state[:teleporter] &&
      Direction.orthogonal_direction(entity_tile, destination) == [destination.parsed_state[:facing]]
  end

  defp _is_pushable(pushable, entity_tile, destination) do
    if entity_tile.parsed_state[:not_pushing] do
      false
    else
      case pushable do
        true  -> _is_pushable("nsew", entity_tile, destination)

        directions when is_binary(directions) ->
          directions
          |> String.split("",trim: true)
          |> Enum.any?(&_in_direction(&1, entity_tile, destination))

        _ -> false
      end
    end
  end

  defp _is_squishable(destination, entity_tile) do
    if entity_tile.parsed_state[:not_squishing] do
      false
    else
      destination.parsed_state[:squishable]
    end
  end

  defp _in_direction(direction, entity_tile, destination) do
    #{row_delta, col_delta} = {destination.row - entity_tile.row, destination.col - entity_tile.col}
    dirs = Direction.orthogonal_direction(entity_tile, destination)
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
  defp _get_direction(entity_tile, destination) do
    Direction.orthogonal_direction(entity_tile, destination)
    |> Enum.at(0)
  end

  defp _possible_teleporter_destinations(_, _state, _candidates, first \\ false)
  defp _possible_teleporter_destinations([], _state, candidates, _first), do: candidates
  defp _possible_teleporter_destinations([_], _state, candidates, _first), do: candidates
  defp _possible_teleporter_destinations([a, b | coordinates], state, candidates, first) do
    tile = Levels.get_tile(state, a)
    candidate_tile = Levels.get_tile(state, b)

    candidates = cond do
                   _is_destination_candidate(tile, candidate_tile, first) -> [candidate_tile | candidates]
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
  defp _is_destination_candidate(tile, candidate_tile, true) do
     tile && candidate_tile && tile.parsed_state[:teleporter]
  end
  defp _is_destination_candidate(tile, candidate_tile, false) do
    _is_teleporter(tile, candidate_tile)
  end

  defp _teleport([], _entity_tile, _state), do: {:invalid}
  defp _teleport([candidate_destination | candidates], %Tile{} = entity_tile, %Levels{} = state) do
    case go(entity_tile, candidate_destination, state) do
      {:ok, _tile_changes, _state} = result->
        result

      _ -> # invalid for whatever reason
        _teleport(candidates, entity_tile, state)
    end
  end
end

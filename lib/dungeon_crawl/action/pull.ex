defmodule DungeonCrawl.Action.Pull do
  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances.MapTile
  alias DungeonCrawl.Scripting.Direction

  @doc """
  Moves the lead tile, and pulls any eligible tiles adjacent to the old space to it. If there
  were no adjacent pullable tiles, then this acts as a simple Move.go. If the lead tile is unable
  to move, {:invalid} is returned. Otherwise returns a tuple containing :ok, a coordinate map of
  tile changes, and the updated instance state.

  ## Examples

    iex> Pull.pull(%MapTile{}, %MapTile{}, %Instances{})
    {:invalid}
    iex> Pull.pull(%MapTile{}, %MapTile{}, %Instances{})
    {:ok, %{ {1,2} => %MapTile{}, {2,2} => %MapTile{} }, %Instances{}}
  """
  def pull(%MapTile{} = lead_map_tile, %MapTile{} = destination, %Instances{} = state) do
    # can_move is false if destination is blocking (regardless of it being pushable or squishable. That may change
    # later.
    if Move.can_move(destination) do
      movements =_pull_chain(lead_map_tile, destination, state)
      _execute_pull_chain({:ok, %{}, state}, movements)
    else
      {:invalid}
    end
  end
  def pull(_, _, _), do: {:invalid}

  defp _execute_pull_chain(_tile_changes_and_state_tuple, _pull_chain, _puller \\ nil)
  defp _execute_pull_chain({:ok, tile_changes, state}, [], puller) do
    {_, state} = cond do
                   puller && puller.parsed_state[:pulling] == "map_tile_id" ->
                     Instances.update_map_tile_state(state, puller, %{pulling: false})
                   true ->
                     {puller, state}
                 end
    {:ok, tile_changes, state}
  end
  defp _execute_pull_chain({:ok, tile_changes, state}, [ {lead_map_tile, destination} | pull_chain ], puller) do
    direction = Direction.orthogonal_direction(lead_map_tile, destination) |> Enum.at(0)

    {lead_map_tile, state} = cond do
                               puller && lead_map_tile.parsed_state[:pullable] == "map_tile_id" ->
                                 Instances.update_map_tile_state(state, lead_map_tile, %{pullable: puller.id, facing: direction})
                               direction != lead_map_tile.parsed_state[:facing] ->
                                 Instances.update_map_tile_state(state, lead_map_tile, %{facing: direction})
                               true ->
                                 {lead_map_tile, state}
                             end

    {_, state} = cond do
                   puller && puller.parsed_state[:pulling] == "map_tile_id" ->
                     Instances.update_map_tile_state(state, puller, %{pulling: lead_map_tile.id})
                   true ->
                     {puller, state}
                 end

    destination = (Instances.get_map_tile(state, destination) # really only care about row,col and z_index here
                  || Map.merge(destination, %{z_index: -1}) )
    Move.go(lead_map_tile, destination, state, :absolute, tile_changes)
    |> _execute_pull_chain(pull_chain, lead_map_tile)
  end

  defp _pull_chain(lead_map_tile, destination, state) do
    _pull_chain(lead_map_tile, destination, state, [])
    |> Enum.reverse
  end

  defp _pull_chain(lead_map_tile, destination, state, pull_chain) do
    pulled_tile = ["north", "south", "east", "west"]
                  |> Enum.map(fn(direction) -> Instances.get_map_tile(state, lead_map_tile, direction) end)
                  |> Enum.filter(fn(adjacent) -> can_pull(lead_map_tile, adjacent, destination, pull_chain) end)
                  |> Enum.reject(fn(adjacent) -> would_not_pull(lead_map_tile, adjacent) end)
                  |> Enum.shuffle()
                  |> Enum.sort_by(fn pulled_tile ->
                       {pulled_tile.parsed_state[:pullable] == lead_map_tile.id, pulled_tile.parsed_state[:pullable] == "map_tile_id"}
                     end, &>=/2)
                  |> Enum.at(0) # in case there are several pullable candidates, and because Enum.random errors when given empty list

    if pulled_tile do
      if pulled_tile.parsed_state[:pulling] do
        _pull_chain(pulled_tile, lead_map_tile, state, [ {lead_map_tile, destination} | pull_chain])
      else
        [{pulled_tile, lead_map_tile}, {lead_map_tile, destination} | pull_chain]
      end
    else
      [{lead_map_tile, destination} | pull_chain]
    end
  end

  @doc """
  Returns true if the tile would not pull an adjacent one. For most cases, the tile would pull
  if it is pulling. However, when that tile's `pulling` state value is an integer, it will only pull
  an adjacent tile that has the integer as its id.
  """
  def would_not_pull(tile, adjacent_tile) do
    is_integer(tile.parsed_state[:pulling]) &&
      tile.parsed_state[:pulling] != adjacent_tile.id
  end

  @doc """
  Returns if a `tile` can be pulled by an `adjacent_tile` in the given `direction`.
  Various conditions exist (such as if the adjacent tile cannot be pulled, or can only
  be pulled in certain directions) that this will check, returning true or false.
  """
  def can_pull(tile, adjacent_tile, destination, pull_chain \\ [])
  def can_pull(%MapTile{} = tile, %MapTile{} = adjacent_tile, %MapTile{} = destination, pull_chain) do
    can_pull(tile, adjacent_tile, _get_direction(tile, destination), pull_chain)
  end
  def can_pull(%MapTile{} = tile, %MapTile{} = adjacent_tile, direction, pull_chain) do
    if direction == _get_direction(tile, adjacent_tile) || _already_pulling(adjacent_tile, pull_chain) do
      false
    else
      case adjacent_tile.parsed_state[:pullable] do
        true          -> true
        false         -> false
        "linear"      -> _get_direction(adjacent_tile, tile) == direction
        "map_tile_id" -> true
        directions when is_binary(directions) ->
            directions
            |> String.split("",trim: true)
            |> Enum.any?(&_in_direction(&1, adjacent_tile, tile))
        map_tile_id -> tile.id == map_tile_id
      end
    end
  end
  def can_pull(_, _, _, _), do: false

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

  defp _already_pulling(_tile, []), do: false
  defp _already_pulling(tile, [ {leader, _follower } | pull_chain]) do
    tile == leader || _already_pulling(tile, pull_chain)
  end
end

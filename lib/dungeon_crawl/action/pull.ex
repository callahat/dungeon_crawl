defmodule DungeonCrawl.Action.Pull do
  alias DungeonCrawl.Action.Move
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.DungeonInstances.Tile
  alias DungeonCrawl.Scripting.Direction
require Logger
  @doc """
  Moves the lead tile, and pulls any eligible tiles adjacent to the old space to it. If there
  were no adjacent pullable tiles, then this acts as a simple Move.go. If the lead tile is unable
  to move, {:invalid, tile_changes, state} is returned. Otherwise returns a tuple containing :ok,
  a coordinate map of tile changes, and the updated instance state.
  :invalid implies that the state was not changed as the tile pulling was unable to take its move.
  Only the tile on the top of the stack can be pulled.

  ## Examples

    iex> Pull.pull(%Tile{}, %Tile{}, %Levels{})
    {:invalid, %{}, %Levels{}}
    iex> Pull.pull(%Tile{}, %Tile{}, %Levels{})
    {:ok, %{ {1,2} => %Tile{}, {2,2} => %Tile{} }, %Levels{}}
  """
  def pull(%Tile{} = lead_tile, %Tile{} = destination, %Levels{} = state) do
    movements =_pull_chain(lead_tile, destination, state)
    _execute_pull_chain({:ok, %{}, state}, movements)
  end
  def pull(_, _, state), do: {:invalid, %{}, state}

  defp _execute_pull_chain(_tile_changes_and_state_tuple, _pull_chain, _puller \\ nil)
  defp _execute_pull_chain({:invalid, tile_changes, state}, _pull_chain, _puller) when tile_changes == %{},
    do: {:invalid, %{}, state}
  defp _execute_pull_chain({:invalid, tile_changes, state}, _pull_chain, _puller),
    do: {:ok, tile_changes, state}
  defp _execute_pull_chain({:ok, tile_changes, state}, [], puller) do
    {_, state} = cond do
                   puller && Enum.member?(["map_tile_id", "tile_id"], puller.parsed_state[:pulling]) ->
                     Levels.update_tile_state(state, puller, %{pulling: false})
                   true ->
                     {puller, state}
                 end
    {:ok, tile_changes, state}
  end
  defp _execute_pull_chain({:ok, tile_changes, state}, [ {lead_tile, destination} | pull_chain ], puller) do
    direction = Direction.orthogonal_direction(lead_tile, destination) |> Enum.at(0)

    destination = (Levels.get_tile(state, destination) # really only care about row,col and z_index here
                  || Map.merge(destination, %{z_index: -1}) )

    case Move.go(lead_tile, destination, state, tile_changes) do
      {:ok, tile_changes, state} ->
        lead_tile = Levels.get_tile_by_id(state, lead_tile)
        lead_pullable = lead_tile && lead_tile.parsed_state[:pullable]
        puller_pulling = puller && puller.parsed_state[:pulling]

        {lead_tile, state} = cond do
                                   Enum.member?(["map_tile_id", "tile_id"], lead_pullable) ->
                                     Levels.update_tile_state(state, lead_tile, %{pullable: puller.id, facing: direction})
                                   puller && is_binary(lead_pullable) && puller.parsed_state[String.to_atom(lead_pullable)] ->
                                     Levels.update_tile_state(state, lead_tile, %{pullable: puller.id, facing: direction})
                                   direction != lead_tile.parsed_state[:facing] ->
                                     Levels.update_tile_state(state, lead_tile, %{facing: direction})
                                   true ->
                                     {lead_tile, state}
                                 end

        {_, state} = cond do
                       Enum.member?(["map_tile_id", "tile_id"], puller_pulling) ->
                         Levels.update_tile_state(state, puller, %{pulling: lead_tile.id})
                       lead_tile && is_binary(puller_pulling) && lead_tile.parsed_state[String.to_atom(puller_pulling)] ->
                         Levels.update_tile_state(state, puller, %{pulling: lead_tile.id})
                       true ->
                         {puller, state}
                     end

        _execute_pull_chain({:ok, tile_changes, state}, pull_chain, lead_tile)

      {:invalid, tile_changes, state} when tile_changes == %{}->
        {:invalid, %{}, state}

      {:invalid, tile_changes, state} ->
        {:ok, tile_changes, state}
    end
  end

  defp _pull_chain(lead_tile, destination, state) do
    _pull_chain(lead_tile, destination, state, [])
    |> Enum.reverse
  end

  defp _pull_chain(lead_tile, destination, state, pull_chain) do
    pulled_tile = ["north", "south", "east", "west"]
                  |> Enum.map(fn(direction) -> Levels.get_tile(state, lead_tile, direction) end)
                  |> Enum.filter(fn(adjacent) -> can_pull(lead_tile, adjacent, destination, pull_chain) end)
                  |> Enum.reject(fn(adjacent) -> would_not_pull(lead_tile, adjacent) end)
                  |> Enum.shuffle()
                  |> Enum.sort_by(fn pulled_tile ->
                       {pulled_tile.parsed_state[:pullable] == lead_tile.id, is_binary(pulled_tile.parsed_state[:pullable]) }
                     end, &>=/2)
                  |> Enum.at(0) # in case there are several pullable candidates, and because Enum.random errors when given empty list

    if pulled_tile do
      if pulled_tile.parsed_state[:pulling] do
        _pull_chain(pulled_tile, lead_tile, state, [ {lead_tile, destination} | pull_chain])
      else
        [{pulled_tile, lead_tile}, {lead_tile, destination} | pull_chain]
      end
    else
      [{lead_tile, destination} | pull_chain]
    end
  end

  @doc """
  Returns true if the tile would not pull an adjacent one. For most cases, the tile would pull
  if it is pulling. However, when that tile's `pulling` state value is an integer, it will only pull
  an adjacent tile that has the integer as its id.
  """
  def would_not_pull(tile, adjacent_tile) do
    is_integer(tile.parsed_state[:pulling]) &&
      tile.parsed_state[:pulling] != adjacent_tile.id ||
    is_binary(tile.parsed_state[:pulling]) &&
      !Enum.member?(["linear", "map_tile_id", "tile_id"], tile.parsed_state[:pulling]) &&
      !(tile.parsed_state[:pulling] =~ ~r/\A[nsew]{1,4}\z/) &&
      !adjacent_tile.parsed_state[String.to_atom(tile.parsed_state[:pulling])]
  end

  @doc """
  Returns if a `tile` can be pulled by an `adjacent_tile` in the given `direction`.
  Various conditions exist (such as if the adjacent tile cannot be pulled, or can only
  be pulled in certain directions) that this will check, returning true or false.
  """
  def can_pull(tile, adjacent_tile, destination, pull_chain \\ [])
  def can_pull(%Tile{} = tile, %Tile{} = adjacent_tile, %Tile{} = destination, pull_chain) do
    can_pull(tile, adjacent_tile, _get_direction(tile, destination), pull_chain)
  end
  def can_pull(%Tile{} = tile, %Tile{} = adjacent_tile, direction, pull_chain) do
    if direction == _get_direction(tile, adjacent_tile) || _already_pulling(adjacent_tile, pull_chain) do
      false
    else
      case adjacent_tile.parsed_state[:pullable] do
        true          -> true
        false         -> false
        "linear"      -> _get_direction(adjacent_tile, tile) == direction
        "map_tile_id" -> true
        "tile_id"     -> true
        directions when is_binary(directions) ->
          if directions =~ ~r/\A[nsew]{1,4}\z/ do
            directions
            |> String.split("",trim: true)
            |> Enum.any?(&_in_direction(&1, adjacent_tile, tile))
          else
            # assume its a state variable
            tile.parsed_state[String.to_atom(directions)]
          end
        puller_tile_id -> tile.id == puller_tile_id
      end
    end
  end
  def can_pull(_, _, _, _), do: false

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

  defp _already_pulling(_tile, []), do: false
  defp _already_pulling(tile, [ {leader, _follower } | pull_chain]) do
    tile == leader || _already_pulling(tile, pull_chain)
  end
end

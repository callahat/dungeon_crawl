defmodule DungeonCrawl.DungeonProcesses.Instances do
  @moduledoc """
  The instances context.
  It wraps the retrival and changes of %Instances{}
  """

  defstruct program_contexts: %{}, map_by_ids: %{}, map_by_coords: %{}, dirty_ids: %{}

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.TileState
  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Runner

  require Logger

  @doc """
  Returns the top map tile in the given directon from the provided coordinates.
  """
  def get_map_tile(state, %{row: row, col: col} = _map_tile, direction) do
    {d_row, d_col} = _direction_delta(direction)
    get_map_tile(state, %{row: row + d_row, col: col + d_col})
  end
  def get_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, %{row: row, col: col} = _map_tile) do
    with tiles when is_map(tiles) <- by_coords[{row, col}],
         [{_z_index, top_tile}] <- Map.to_list(tiles)
                                   |> Enum.sort(fn({a,_},{b,_}) -> a > b end)
                                   |> Enum.take(1) do
      by_id[top_tile]
    else
      _ ->
        nil
    end
  end

  @doc """
  Returns the map tiles in the given directon from the provided coordinates.
  """
  def get_map_tiles(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, %{row: row, col: col} = map_tile, direction) do
    {d_row, d_col} = _direction_delta(direction)
    Instances.get_map_tiles(state, %{row: row + d_row, col: col + d_col})
  end
  def get_map_tiles(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, %{row: row, col: col} = map_tile) do
    with tiles when is_map(tiles) <- by_coords[{row, col}],
         tiles <- Map.to_list(tiles)
                  |> Enum.sort(fn({a,_},{b,_}) -> a > b end)
                  |> Enum.map(fn({_, tile_id}) -> by_id[tile_id] end) do
      tiles
    else
      _ ->
        []
    end
  end

  @doc """
  Gets the map tile given by the id.
  """
  def get_map_tile_by_id(%Instances{map_by_ids: by_id} = state, %{id: map_tile_id} = map_tile) do
    by_id[map_tile_id]
  end

  @doc """
  Returns true or false, depending on if the given tile_id responds to the event.
  """
  def responds_to_event?(%Instances{program_contexts: program_contexts} = state, %{id: map_tile_id}, event) do
    with %{^map_tile_id => %{program: program}} <- program_contexts,
         labels <- program.labels[event],
         true <- is_list(labels) do
      Enum.any?(labels, fn([_, active]) -> active end)
    else
      _ ->
        false
    end
  end

  @doc """
  Send an event to a tile/program.
  Returns the updated state.
  """
  def send_event(%Instances{program_contexts: program_contexts} = state, %{id: map_tile_id}, event, %DungeonCrawl.Player.Location{} = sender) do
IO.puts "HERE"
    case program_contexts do
      %{^map_tile_id => %{program: program, object: object}} ->
IO.puts "now here"
        %Runner{program: program, object: object, state: state} = Scripting.Runner.run(%Runner{program: program, object: object, state: state}, event)
                                  |> Map.put(:event_sender, sender)
                                  |> handle_broadcasting()
IO.puts "Made it here?"
        if program.status == :dead do
          %Instances{ state | program_contexts: Map.delete(program_contexts, map_tile_id)}
        else
          updated_program_context = %{program: program, object: object, event_sender: sender}
          %Instances{ state | program_contexts: Map.put(program_contexts, map_tile_id, updated_program_context)}
        end

      _ ->
        state
    end
  end

  @doc """
  Creates the given map tile in the parent instance state if it does not already exist.
  Returns a tuple containing the created (or already existing) tile, and the updated (or same) state.
  Does not update `dirty_ids` since this tile should already exist in the DB for it to have an id.
  """
  def create_map_tile(%Instances{} = state, map_tile) do
    map_tile = case TileState.Parser.parse(map_tile.state) do
                 {:ok, state} -> Map.put(map_tile, :parsed_state, state)
                 _            -> map_tile
               end
    {map_tile, state} = _register_map_tile(state, map_tile)
    case Scripting.Parser.parse(map_tile.script) do
     {:ok, program} ->
       unless program.status == :dead do
         {map_tile, _start_program(state, map_tile.id, %{program: program, object: map_tile, event_sender: nil})}
       else
         {map_tile, state}
       end
     other ->
       Logger.warn """
                   Possible corrupt script for map tile instance: #{inspect map_tile}
                   Not :ok response: #{inspect other}
                   """
       {map_tile, state}
    end
  end

  defp _register_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, map_tile) do
     if Map.has_key?(by_id, map_tile.id) do
      # Tile already registered
      {by_id[map_tile.id], state}
    else
      z_index_map = by_coords[{map_tile.row, map_tile.col}] || %{}
      if Map.has_key?(z_index_map, map_tile.z_index) do
        # don't overwrite and add the tile if there's already one registered there
        {by_id[z_index_map[map_tile.z_index]], state}
      else
        by_id = Map.put(by_id, map_tile.id, map_tile)
        by_coords = Map.put(by_coords, {map_tile.row, map_tile.col},
                            Map.put(z_index_map, map_tile.z_index, map_tile.id))
        {map_tile, %Instances{ state | map_by_ids: by_id, map_by_coords: by_coords }}
      end
    end
  end

  defp _start_program(%Instances{program_contexts: program_contexts} = state, map_tile_id, program_context) do
    if Map.has_key?(program_contexts, map_tile_id) do
      # already a running program for that tile id, or there is no map tile for that id
      state
    else
      %Instances{ state | program_contexts: Map.put(program_contexts, map_tile_id, program_context)}
    end
  end

  @doc """
  Updates the given map tile in the parent instance process, and returns the updated tile and new state
  """
  def update_map_tile(%Instances{map_by_ids: by_id, map_by_coords: by_coords} = state, %{id: map_tile_id}, new_attributes) do
    new_attributes = Map.delete(new_attributes, :id)
    previous_update = state.dirty_ids[map_tile_id] || %{}

    updated_tile = by_id[map_tile_id] |> Map.merge(new_attributes)

    old_tile_coords = Map.take(by_id[map_tile_id], [:row, :col, :z_index])
    updated_tile_coords = Map.take(updated_tile, [:row, :col, :z_index])

    by_id = Map.put(by_id, map_tile_id, updated_tile)
    dirty_ids = Map.put(state.dirty_ids, map_tile_id, Map.merge(previous_update, new_attributes))

    if updated_tile_coords != old_tile_coords do
      z_index_map = by_coords[{updated_tile_coords.row, updated_tile_coords.col}] || %{}

      if Map.has_key?(z_index_map, updated_tile_coords.z_index) do
        # invalid update, just throw it away (or maybe raise an error instead of silently doing nothing)
        {nil, state}
      else
        by_coords = _remove_coord(by_coords, Map.take(old_tile_coords, [:row, :col, :z_index]))
                    |> _put_coord(Map.take(updated_tile_coords, [:row, :col, :z_index]), map_tile_id)
        {updated_tile, %Instances{ state | map_by_ids: by_id, map_by_coords: by_coords, dirty_ids: dirty_ids }}
      end
    else
      {updated_tile, %Instances{ state | map_by_ids: by_id, dirty_ids: dirty_ids }}
    end
  end

  @doc """
  Deletes the given map tile from the instance state.
  Returns a tuple containing the deleted tile (nil if no tile was deleted) and the updated state.
  """
  def delete_map_tile(%Instances{program_contexts: program_contexts, map_by_ids: by_id, map_by_coords: by_coords} = state, %{id: map_tile_id}) do
    program_contexts = Map.delete(program_contexts, map_tile_id)
    dirty_ids = Map.put(state.dirty_ids, map_tile_id, :deleted)

    map_tile = by_id[map_tile_id]

    if map_tile do
      z_index_map = by_coords[{map_tile.row, map_tile.col}] || %{}
      by_coords = _remove_coord(by_coords, Map.take(map_tile, [:row, :col, :z_index]))
      by_id = Map.delete(by_id, map_tile_id)
      {map_tile, %Instances{ program_contexts: program_contexts, map_by_ids: by_id, map_by_coords: by_coords, dirty_ids: dirty_ids }}
    else
      {nil, state}
    end
  end

  @doc """
  Takes a program context, and sends all queued up broadcasts. Returns the context with broadcast queues emtpied.
  """
  def handle_broadcasting(runner_context) do
    _handle_broadcasts(runner_context.program.broadcasts, "dungeons:#{runner_context.object.map_instance_id}")
    _handle_broadcasts(runner_context.program.responses, runner_context.event_sender)
    %{ runner_context | program: %{ runner_context.program | responses: [], broadcasts: [] } }
  end

  defp _handle_broadcasts([ [event, payload] | messages], socket) when is_binary(socket) do
    DungeonCrawlWeb.Endpoint.broadcast socket, event, payload
    _handle_broadcasts(messages, socket)
  end
  defp _handle_broadcasts([message | messages], player_location = %DungeonCrawl.Player.Location{}) do
    DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", "message", %{message: message}
    _handle_broadcasts(messages, player_location)
  end
  defp _handle_broadcasts(_, _), do: nil

  @directions %{
    "up"    => {-1,  0},
    "down"  => { 1,  0},
    "left"  => { 0, -1},
    "right" => { 0,  1},
    "north" => {-1,  0},
    "south" => { 1,  0},
    "west"  => { 0, -1},
    "east"  => { 0,  1}
  }

  @no_direction { 0,  0}

  defp _direction_delta(direction) do
    @directions[direction] || @no_direction
  end

  defp _remove_coord(by_coords, %{row: row, col: col, z_index: z_index}) do
    z_indexes = case Map.fetch(by_coords, {row, col}) do
                  {:ok, z_index_map} -> Map.delete(z_index_map, z_index)
                  _                  -> %{}
                end
    Map.put(by_coords, {row, col}, z_indexes)
  end

  defp _put_coord(by_coords, %{row: row, col: col, z_index: z_index}, map_tile_id) do
    z_indexes = case Map.fetch(by_coords, {row, col}) do
                  {:ok, z_index_map} -> Map.put(z_index_map, z_index, map_tile_id)
                  _                  -> %{z_index => map_tile_id}
                end
    Map.put(by_coords, {row, col}, z_indexes)
  end
end


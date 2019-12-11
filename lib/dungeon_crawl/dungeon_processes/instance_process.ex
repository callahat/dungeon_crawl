defmodule DungeonCrawl.DungeonProcesses.InstanceProcess do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.Scripting
  alias DungeonCrawl.TileState

  ## Client API

  @timeout 100

  @doc """
  Starts the instance process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Initializes the dungeon map instance and starts the programs.
  """
  def load_map(instance, map_tiles) do
    # Start programs for now, later load everything
    # When everything is loaded, the object in the program context will be replaced with a reference to the map tile
    # stored by the instance_process.
    map_tiles
    |> Enum.each( fn(map_tile) ->
         map_tile = case TileState.Parser.parse(map_tile.state) do
                      {:ok, state} -> Map.put(map_tile, :parsed_state, state)
                      _            -> map_tile
                    end
         GenServer.cast(instance, {:register_map_tile, {map_tile}})

         case Scripting.Parser.parse(map_tile.script) do
           {:ok, program} ->
             unless program.status == :dead do
               GenServer.cast(instance, {:start_program, {map_tile.id, %{program: program, object: map_tile, event_sender: nil} }})
             end
           other ->
             Logger.warn """
                         Possible corrupt script for map tile instance: #{inspect map_tile}
                         Not :ok response: #{inspect other}
                         """
         end
       end )
  end

  @doc """
  Starts the scheduler
  """
  def start_scheduler(instance) do
    Process.send_after(instance, :perform_actions, @timeout)
  end

  @doc """
  Inspect the state
  """
  def inspect_state(instance) do
    GenServer.call(instance, {:inspect})
  end

  @doc """
  Check is a tile/program responds to an event
  """
  def responds_to_event?(instance, tile_id, event) do
    GenServer.call(instance, {:responds_to_event?, {tile_id, event}})
  end

  @doc """
  Send an event to a tile/program.
  """
  def send_event(instance, tile_id, event, sender) do
    GenServer.cast(instance, {:send_event, {tile_id, event, sender}})
  end

  @doc """
  Gets the tile for the given map tile id.
  """
  def get_tile(instance, tile_id) do
    GenServer.call(instance, {:get_map_tile, {tile_id}})
  end

  @doc """
  Gets the tile for the given row, col coordinates. If there are many tiles there,
  the tile with the highest (top) z_index is returned.
  """
  def get_tile(instance, row, col) do
    tile_id = GenServer.call(instance, {:get_map_tile, {row, col}})
    get_tile(instance, tile_id)
  end

  @doc """
  Updates the given map_tile.
  """
  def update_tile(instance, tile_id, attrs) do
    GenServer.cast(instance, {:update_map_tile, {tile_id, attrs}})
  end

  ## Defining GenServer Callbacks

  # Possible future state
  # The state of the GenServer is a tuple of three:
  # 1st - Map of tile id (key) to %Program{} (value) for all living programs
  # 2nd - Representation of the entire map. The first element of the tuple 
  #       is a map with tile id (key) and the entire instance %MapTile{} (value).
  #       The second element of the tuple is also a map, is an ordered array of tile ids (value)
  #       in a map by the row, col (key)
  # 3rd - boolean representing if the scheduler is running or not. If not, the
  #       process is in an "idle" state. Otherwise, the process is "active" and
  #       checks all the running programs for activity every XXX ms

  @impl true
  def init(:ok) do
    map = {
            %{}, # MapId => Map Record
            %{}  # {row, col} -> Ordered array of map id's
          }
    active_programs = %{} # map_id associated with program
    {:ok, {active_programs, map}}
  end

  @impl true
  def handle_call({:inspect}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:responds_to_event?, {tile_id, event}}, _from, {program_contexts, map}) do
    with %{^tile_id => %{program: program}} <- program_contexts,
         labels <- program.labels[event],
         true <- is_list(labels) do
      {:reply, Enum.any?(labels, fn([_, active]) -> active end), {program_contexts, map}}
    else
      _ ->
        {:reply, false, {program_contexts, map}}
    end
  end

  @impl true
  def handle_call({:get_map_tile, {tile_id}}, _from, {program_contexts, {by_id, by_coords} = map}) do
    {:reply, by_id[tile_id], {program_contexts, map}}
  end

  @impl true
  def handle_call({:get_map_tile, {row, col}}, _from, {program_contexts, {by_id, by_coords} = map}) do
    with tiles when is_map(tiles) <- by_coords[{row, col}],
         [{z_index, top_tile}] <- Map.to_list(tiles)
                                  |> Enum.sort(fn({a,_},{b,_}) -> b > a end)
                                  |> Enum.take(1) do
      {:reply, top_tile, {program_contexts, map}}
    else
      _ ->
        {:reply, nil, {program_contexts, map}}
    end
  end

  @impl true
  def handle_cast({:start_program, {map_tile_id, program_context}}, {program_contexts, map}) do
    if Map.has_key?(program_contexts, map_tile_id) do
      # already a running program for that tile id, or there is no map tile for that id
      {:noreply, {program_contexts, map}}
    else
      {:noreply, {Map.put(program_contexts, map_tile_id, program_context), map}}
    end
  end

  @impl true
  def handle_cast({:register_map_tile, {map_tile}}, {program_contexts, {by_id, by_coords} = map}) do
    if Map.has_key?(by_id, map_tile.id) do
      # already a running program for that tile id, or there is no map tile for that id
      {:noreply, {program_contexts, map}}
    else
      by_id = Map.put(by_id, map_tile.id, map_tile)
      z_indexes = case Map.fetch(by_coords, {map_tile.row, map_tile.col}) do
                    {:ok, z_index_map} -> Map.put(z_index_map, map_tile.z_index, map_tile.id)
                    _                  -> %{map_tile.z_index => map_tile.id}
                  end
      by_coords = Map.put(by_coords, {map_tile.row, map_tile.col}, z_indexes)
      {:noreply, {program_contexts, {by_id, by_coords}}}
    end
  end

  @impl true
  def handle_cast({:send_event, {tile_id, event, sender = %DungeonCrawl.Player.Location{}}}, {program_contexts, map}) do
    case program_contexts do
      %{^tile_id => %{program: program, object: object}} ->
        updated_program_context = Scripting.Runner.run(%{program: program, object: object, label: event})
                                  |> Map.put(:event_sender, sender)
                                  |> _handle_broadcasting()
        if updated_program_context.program.status == :dead do
          {:noreply, { Map.delete(program_contexts, tile_id), map}}
        else
          {:noreply, { Map.put(program_contexts, tile_id, Map.put(updated_program_context, :event_sender, sender)), map}}
        end

      _ ->
        {:noreply, {program_contexts, map}}
    end
  end

  @impl true
  def handle_cast({:update_map_tile, {tile_id, new_attributes}}, {program_contexts, {by_id, by_coords} = map}) do
    updated_tile = by_id[tile_id] |> Map.merge(new_attributes)
    old_tile_coords = Map.take(by_id[tile_id], [:row, :col, :z_index])
    updated_tile_coords = Map.take(updated_tile, [:row, :col, :z_index])
    by_ids = Map.put(by_id, tile_id, updated_tile)

    by_coords = if updated_tile_coords != old_tile_coords do
                   _remove_coord(by_coords, Map.take(old_tile_coords, [:row, :col, :z_index]))
                   |> _put_coord(Map.take(old_tile_coords, [:row, :col, :z_index]), tile_id)
                else
                  by_coords
                end

    {:noreply, {program_contexts, {by_id, by_coords}}}
  end

  @impl true
  def handle_info(:perform_actions, {program_contexts, map}) do
    updated_program_contexts = _cycle_programs(program_contexts)
    _schedule()

    {:noreply, {updated_program_contexts, map}}
  end

  defp _schedule do
    Process.send_after(self(), :perform_actions, @timeout)
  end

  @doc """
  Cycles through all the programs, running each until a wait point. Any messages for broadcast or a single player
  will be broadcast. Typically this will only be called by the scheduler.
  """
  defp _cycle_programs(program_contexts) when is_map(program_contexts) do
    program_contexts
    |> Enum.flat_map(fn({k,v}) -> [[k,v]] end)
    |> _cycle_programs()
    |> Map.new(fn [k,v] -> {k,v} end)
  end

  defp _cycle_programs([]), do: []
  defp _cycle_programs([[line, program_context] | program_contexts]) do
    updated_program_context = Scripting.Runner.run(program_context)
                              |> Map.put(:event_sender, program_context.event_sender)
                              |> _handle_broadcasting()

    if updated_program_context.program.status == :dead do
      [ _cycle_programs(program_contexts) ]
    else
      [ [line, updated_program_context] | _cycle_programs(program_contexts) ]
    end
  end

  defp _handle_broadcasting(program_context) do
    _handle_broadcasts(program_context.program.broadcasts, "dungeons:#{program_context.object.map_instance_id}")
    _handle_broadcasts(program_context.program.responses, program_context.event_sender)

    %{ program_context | program: %{ program_context.program | responses: [], broadcasts: [] } }
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
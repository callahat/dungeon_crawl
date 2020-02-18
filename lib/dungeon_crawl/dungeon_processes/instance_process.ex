defmodule DungeonCrawl.DungeonProcesses.InstanceProcess do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonInstances

  ## Client API

  @timeout 100
  @db_update_timeout 5000

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
    map_tiles
    |> Enum.each( fn(map_tile) ->
         GenServer.cast(instance, {:create_map_tile, {map_tile}})
       end )
  end

  @doc """
  Starts the scheduler
  """
  def start_scheduler(instance) do
    Process.send_after(instance, :perform_actions, @timeout)
    Process.send_after(instance, :write_db, @db_update_timeout)
  end

  @doc """
  Inspect the state
  """
  def get_state(instance) do
    GenServer.call(instance, {:get_state})
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
    GenServer.call(instance, {:get_map_tile, {row, col}})
  end

  @doc """
  Gets the tile for the given row, col coordinates one away in the given direction.
  If there are many tiles there, the tile with the highest (top) z_index is returned.
  """
  def get_tile(instance, row, col, direction) do
    GenServer.call(instance, {:get_map_tile, {row, col, direction}})
  end

  @doc """
  Gets the tiles for the given row, col coordinates.
  """
  def get_tiles(instance, row, col) do
    GenServer.call(instance, {:get_map_tiles, {row, col}})
  end

  @doc """
  Gets the tiles for the given row, col coordinates one away in the given direction.
  """
  def get_tiles(instance, row, col, direction) do
    GenServer.call(instance, {:get_map_tiles, {row, col, direction}})
  end

  @doc """
  Updates the given map_tile.
  """
  def update_tile(instance, tile_id, attrs) do
    GenServer.cast(instance, {:update_map_tile, {tile_id, attrs}})
  end

  @doc """
  Deletes the given map tile.
  """
  def delete_tile(instance, tile_id) do
    GenServer.cast(instance, {:delete_map_tile, {tile_id}})
  end

  @doc """
  Runs the given function in the context of the instance process.
  Expects the function passed in to take one parameter; `instance_state`.
  The function should return a tuple containing the return value for `run_with` and
  the modified state for the first and second tuple members respectively.
  """
  def run_with(instance, func) when is_function(func) do
    GenServer.call(instance, {:run_with, {func}})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, %Instances{}}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:responds_to_event?, {tile_id, event}}, _from, %Instances{} = state) do
    true_or_false = Instances.responds_to_event?(state, %{id: tile_id}, event)
    {:reply, true_or_false, state}
  end

  @impl true
  def handle_call({:get_map_tile, {tile_id}}, _from, %Instances{} = state) do
    map_tile = Instances.get_map_tile_by_id(state, %{id: tile_id})
    {:reply, map_tile, state}
  end

  @impl true
  def handle_call({:get_map_tile, {row, col}}, _from, state) do
    map_tile = Instances.get_map_tile(state, %{row: row, col: col})
    {:reply, map_tile, state}
  end

  @impl true
  def handle_call({:get_map_tile, {row, col, direction}}, _from, state) do
    map_tile = Instances.get_map_tile(state, %{row: row, col: col}, direction)
    {:reply, map_tile, state}
  end

  @impl true
  def handle_call({:get_map_tiles, {row, col}}, _from, %Instances{} = state) do
    map_tiles = Instances.get_map_tiles(state, %{row: row, col: col})
    {:reply, map_tiles, state}
  end

  @impl true
  def handle_call({:get_map_tiles, {row, col, direction}}, _from, %Instances{} = state) do
    map_tiles = Instances.get_map_tiles(state, %{row: row, col: col}, direction)
    {:reply, map_tiles, state}
  end

  @impl true
  def handle_call({:run_with, {function}}, _from, %Instances{} = state) when is_function(function) do
    {return_value, state} = function.(state)
    {:reply, return_value, state}
  end

  @impl true
  def handle_cast({:create_map_tile, {map_tile}}, %Instances{} = state) do
    {_map_tile, state} = Instances.create_map_tile(state, map_tile)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_event, {tile_id, event, %DungeonCrawl.Player.Location{} = sender}}, %Instances{} = state) do
    state = Instances.send_event(state, %{id: tile_id}, event, sender)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_map_tile, {tile_id, new_attributes}}, %Instances{} = state) do
    {_updated_tile, state} = Instances.update_map_tile(state, %{id: tile_id}, new_attributes)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_map_tile, {map_tile_id}}, %Instances{} = state) do
    {_deleted_tile, state} = Instances.delete_map_tile(state, %{id: map_tile_id})
    {:noreply, state}
  end

  @impl true
  def handle_info(:perform_actions, %Instances{program_contexts: program_contexts} = state) do
    {updated_program_contexts, state} = _cycle_programs(program_contexts, state)
    Process.send_after(self(), :perform_actions, @timeout)

    {:noreply, %Instances{ state | program_contexts: updated_program_contexts}}
  end

  @impl true
  def handle_info(:write_db, %Instances{dirty_ids: dirty_ids} = state) do
    # :deleted
    # :updated
    [deletes, updates] = dirty_ids
                         |> Map.to_list
                         |> Enum.split_with(fn({_, event}) -> event == :deleted end)
                         |> Tuple.to_list()
                         |> Enum.map(fn(items) ->
                              Enum.map(items, fn({id,_}) -> id end)
                            end)

    updates = updates -- deletes

    if deletes != [] do
      deletes |> DungeonInstances.delete_map_tiles()
    end

    if updates != [] do
      updates
      |> Enum.map(fn(updated_id) ->
           dirty_ids[updated_id]
         end)
      |> DungeonInstances.update_map_tiles()
    end

    Process.send_after(self(), :write_db, @db_update_timeout)

    {:noreply, %Instances{ state | dirty_ids: %{}}}
  end

  #Cycles through all the programs, running each until a wait point. Any messages for broadcast or a single player
  #will be broadcast. Typically this will only be called by the scheduler.
  # state is passed in mainly so the map can be updated, the program_contexts in state are updated outside.
  defp _cycle_programs(program_contexts, state) when is_map(program_contexts) do
    {program_contexts, state} = program_contexts
                                |> Enum.flat_map(fn({k,v}) -> [[k,v]] end)
                                |> _cycle_programs(state)
    program_contexts = Map.new(program_contexts, fn [k,v] -> {k,v} end)
    {program_contexts, state}
  end

  defp _cycle_programs([], state), do: {[], state}
  defp _cycle_programs([[line, program_context] | program_contexts], state) do
    runner_state = Scripting.Runner.run(%Runner{program: program_context.program, object: program_context.object, state: state})
                              |> Map.put(:event_sender, program_context.event_sender)
                              |> Instances.handle_broadcasting()

    {other_program_contexts, updated_state} = _cycle_programs(program_contexts, runner_state.state)

    if runner_state.program.status == :dead do
      { other_program_contexts, updated_state}
    else
      {[ [line, Map.take(runner_state, [:program, :object, :event_sender])] | other_program_contexts ], updated_state}
    end
  end
end

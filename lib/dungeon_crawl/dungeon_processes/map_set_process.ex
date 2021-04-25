defmodule DungeonCrawl.DungeonProcesses.MapSetProcess do
  use GenServer, restart: :temporary

  require Logger

  defstruct map_set_id: nil,
            map_set_instance: nil,
            state_values: %{},
            instance_registry: %{},
            entrances: []

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.MapSetProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry

  @timeout 60_000

  ## Client API

  @doc """
  Starts the instance process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Sets the map set id
  """
  def set_map_set_id(server, map_set_id) do
    GenServer.call(server, {:set_map_set_id, map_set_id})
  end

  @doc """
  Sets the map set instance
  """
  def set_map_set_instance(server, map_set_instance) do
    GenServer.call(server, {:set_map_set_instance, map_set_instance})
  end

  @doc """
  Sets the state values for the map set process. This will overwrite whatever state values currently exist.
  """
  def set_state_values(server, state_values) do
    GenServer.call(server, {:set_state_values, state_values})
  end

  @doc """
  Sets a state value
  """
  def set_state_value(server, key, value) do
    GenServer.call(server, {:set_state_value, key, value})
  end

  @doc """
  Gets a state value
  """
  def get_state_value(server, key) do
    GenServer.call(server, {:get_state_value, key})
  end

  @doc """
  Looks up the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, pid}` if the instance exists, `:error` otherwise
  """
  def get_instance_registry(server) do
    GenServer.call(server, {:get_instance_registry})
  end

  @doc """
  Gets the map set id
  """
  def get_map_set_id(server) do
    GenServer.call(server, {:get_map_set_id})
  end

  @doc """
  Inspect the state
  """
  def get_state(server) do
    GenServer.call(server, {:get_state})
  end

  @doc """
  Loads a map instance and adds it on the instance registry.
  """
  def load_instance(server, map_instance_id) when is_integer(map_instance_id) do
    load_instance(server, DungeonInstances.get_map(map_instance_id))
  end

  def load_instance(server, map_instance) do
    GenServer.call(server, {:load_instance, map_instance})
  end

  @doc """
  Starts the scheduler which checks for players periodically. If there are none, terminates the
  process and handles the database tables appropriately (ie, deletes them)
  """
  def start_scheduler(server, timeout \\ @timeout) do
    Process.send_after(server, :check_for_players, timeout)
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, instance_registry} = InstanceRegistry.start_link(self(), [])
# might need this
#    InstanceRegistry.link_map_set(program_registry, self())
    {:ok, %MapSetProcess{instance_registry: instance_registry}}
  end

  @impl true
  def handle_call({:set_map_set_id, map_set_id}, _from, state) do
    {:reply, :ok, %{ state | map_set_id: map_set_id }}
  end

  @impl true
  def handle_call({:set_map_set_instance, map_set_instance}, _from, state) do
    {:reply, :ok, %{ state | map_set_instance: map_set_instance }}
  end

  @impl true
  def handle_call({:set_state_values, state_values}, _from, state) do
    {:reply, :ok, %{ state | state_values: state_values }}
  end

  @impl true
  def handle_call({:set_state_value, key, value}, _from, %{state_values: state_values} = state) do
    state_values = Map.put(state_values, key, value)
    {:reply, :ok, %{ state | state_values: state_values }}
  end

  @impl true
  def handle_call({:get_state_value, key}, _from, %{state_values: state_values} = state) do
    {:reply, state_values[key], state}
  end

  @impl true
  def handle_call({:get_instance_registry}, _from, state) do
    {:reply, state.instance_registry, state}
  end

  @impl true
  def handle_call({:get_map_set_id}, _from, state) do
    {:reply, state.map_set_id, state}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:load_instance, map_instance}, _from, state) do
    InstanceRegistry.create(state.instance_registry, map_instance)

    if map_instance.entrance do
      {:reply, :ok, %{ state | entrances: [ map_instance.id | state.entrances ] }}
    else
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info(:check_for_players, state) do
    if Enum.count(InstanceRegistry.player_location_ids(state.instance_registry)) > 0 do
      Process.send_after(self(), :check_for_players, @timeout)

      {:noreply, state}
    else
      # for now, delete the backing db and stop the processes. Maybe later have map set instances be configurable
      # to stick around when empty (but idle the processes)
      Logger.info "Map Set Process ##{state.map_set_instance.id} terminating after a period of time with no players"
      DungeonInstances.delete_map_set(state.map_set_instance)
      {:stop, :normal, state}
    end
  end
end


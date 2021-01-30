defmodule DungeonCrawl.DungeonProcesses.MapSetProcess do
  use GenServer, restart: :temporary

  defstruct map_set_instance: nil,
            state_values: %{},
            instance_registry: nil,
            entrances: []

  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.DungeonProcesses.MapSetProcess
  alias DungeonCrawl.DungeonProcesses.InstanceRegistry

  ## Client API

  @doc """
  Starts the instance process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
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

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, instance_registry} = InstanceRegistry.start_link(self(), [])
# might need this
#    InstanceRegistry.link_map_set(program_registry, self())
    {:ok, %MapSetProcess{instance_registry: instance_registry}}
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
end


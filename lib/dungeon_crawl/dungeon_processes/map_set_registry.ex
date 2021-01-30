defmodule DungeonCrawl.DungeonProcesses.MapSetRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.DungeonProcesses.{MapSetProcess}
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Repo
  alias DungeonCrawl.StateValue

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the map_set pid for `map_set_id` stored in `server`.

  Returns `{:ok, pid}` if the map_set exists, `:error` otherwise
  """
  def lookup(server, map_set_id) do
    GenServer.call(server, {:lookup, map_set_id})
  end

  @doc """
  Looks up or creates the map_set pid for `map_set_id` stored in `server`.

  Returns `{:ok, pid}`.
  """
  def lookup_or_create(server, map_set_id) do
    case lookup(server, map_set_id) do
      :error ->
        create(server, map_set_id)
        lookup(server, map_set_id)

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @doc """
  Ensures there is a map_set associated with the given `map_set_id` in `server`.
  """
  def create(server, map_set_id) do
    GenServer.cast(server, {:create, map_set_id})
  end

  @doc """
  Stops the map_set associated with the given `map_set_id` in `server`, allowing it to be removed.
  """
  def remove(server, map_set_id) do
    GenServer.cast(server, {:remove, map_set_id})
  end

  @doc """
  List the map_set ids and the map_set processes they are associated with.
  Gives some insight into what map_set processes are running.
  """
  def list(server) do
    GenServer.call(server, {:list})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, supervisor} = DynamicSupervisor.start_link strategy: :one_for_one
    map_set_ids = %{}
    refs = %{}
    {:ok, {map_set_ids, refs, supervisor}}
  end

  @impl true
  def handle_call({:lookup, map_set_id}, _from, {map_set_ids, _, _} = state) do
    {:reply, Map.fetch(map_set_ids, map_set_id), state}
  end

  @impl true
  def handle_call({:list}, _from, {map_set_ids, _, _} = state) do
    {:reply, map_set_ids, state}
  end

  @impl true
  def handle_cast({:create, map_set_id}, {map_set_ids, refs, supervisor}) do
    if Map.has_key?(map_set_ids, map_set_id) do
      {:noreply, {map_set_ids, refs, supervisor}}
    else
      with msi when not is_nil(msi) <- DungeonInstances.get_map_set(map_set_id) do
        {:ok, state_values} = StateValue.Parser.parse(msi.state)

        {:noreply, _create_map_set(map_set_id, msi, state_values, {map_set_ids, refs, supervisor})}
      else
        _error ->
          Logger.error "Got a CREATE cast for #{map_set_id} but its already been cleared"
          {:noreply, {map_set_ids, refs, supervisor}}
      end
    end
  end

  @impl true
  def handle_cast({:remove, map_set_id}, {map_set_ids, refs, supervisor}) do
    if Map.has_key?(map_set_ids, map_set_id), do: GenServer.stop(Map.fetch!(map_set_ids, map_set_id), :shutdown)
    {:noreply, {map_set_ids, refs, supervisor}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {map_set_ids, refs, supervisor}) do
    {map_set_id, refs} = Map.pop(refs, ref)
    map_set_ids = Map.delete(map_set_ids, map_set_id)
    {:noreply, {map_set_ids, refs, supervisor}}
  end

  defp _create_map_set(map_set_id, map_set_instance, state_values, {map_set_ids, refs, supervisor}) do
    {:ok, map_set_process} = DynamicSupervisor.start_child(supervisor, MapSetProcess)

    MapSetProcess.set_map_set_instance(map_set_process, map_set_instance)
    MapSetProcess.set_state_values(map_set_process, state_values)

    Repo.preload(map_set_instance, :maps).maps
    |> Enum.each(fn map ->
         MapSetProcess.load_instance(map_set_process, map)
       end)

    ref = Process.monitor(map_set_process)
    refs = Map.put(refs, ref, map_set_id)
    map_set_ids = Map.put(map_set_ids, map_set_id, map_set_process)
    {map_set_ids, refs, supervisor}
  end
end

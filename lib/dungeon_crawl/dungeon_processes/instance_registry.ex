defmodule DungeonCrawl.DungeonProcesses.InstanceRegistry do
  use GenServer

  alias DungeonCrawl.DungeonProcesses.{InstanceProcess,Supervisor}
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Repo

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, pid}` if the instance exists, `:error` otherwise
  """
  def lookup(server, instance_id) do
    GenServer.call(server, {:lookup, instance_id})
  end

  @doc """
  Looks up or creates the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, pid}`.
  """
  def lookup_or_create(server, instance_id) do
    case GenServer.call(server, {:lookup, instance_id}) do
      :error ->
        create(server, instance_id)
        GenServer.call(server, {:lookup, instance_id})

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @doc """
  Ensures there is a instance associated with the given `instance_id` in `server`.
  """
  def create(server, instance_id) do
    GenServer.cast(server, {:create, instance_id})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    instance_ids = %{}
    refs = %{}
    {:ok, {instance_ids, refs}}
  end

  @impl true
  def handle_call({:lookup, instance_id}, _from, state) do
    {instance_ids, _} = state
    {:reply, Map.fetch(instance_ids, instance_id), state}
  end
require Logger
  @impl true
  def handle_cast({:create, instance_id}, {instance_ids, refs}) do
    if Map.has_key?(instance_ids, instance_id) do
      {:noreply, {instance_ids, refs}}
    else
      with dungeon_instance when not is_nil(dungeon_instance) <- DungeonInstances.get_map(instance_id) do
        {:ok, instance_process} = DynamicSupervisor.start_child(Supervisor, InstanceProcess)
        InstanceProcess.load_map(instance_process,
                                 Repo.preload(dungeon_instance, :dungeon_map_tiles).dungeon_map_tiles)
        InstanceProcess.start_scheduler(instance_process)
        ref = Process.monitor(instance_process)
        refs = Map.put(refs, ref, instance_id)
        instance_ids = Map.put(instance_ids, instance_id, instance_process)
        {:noreply, {instance_ids, refs}}
      else
        _ -> Logger.error "Got a CREATE cast for #{instance_id} but its already been cleared"
        {:noreply, {instance_ids, refs}}
      end
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {instance_ids, refs}) do
    {instance_id, refs} = Map.pop(refs, ref)
    instance_ids = Map.delete(instance_ids, instance_id)
    {:noreply, {instance_ids, refs}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end

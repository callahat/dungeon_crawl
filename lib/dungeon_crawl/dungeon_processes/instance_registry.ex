defmodule DungeonCrawl.DungeonProcesses.InstanceRegistry do
  use GenServer

  alias DungeonCrawl.DungeonProcesses.{InstanceProcess,Supervisor}

  ## Client API

  @doc """
  Starts the registry.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Looks up the instance pid for `instance_id` stored in `server`.

  Returns `{:ok, pid}` if the instance exists, `:error` otherwise.
  """
  def lookup(server, instance_id) do
    GenServer.call(server, {:lookup, instance_id})
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

  @impl true
  def handle_cast({:create, instance_id}, {instance_ids, refs}) do
    if Map.has_key?(instance_ids, instance_id) do
      {:noreply, {instance_ids, refs}}
    else
      {:ok, pid} = DynamicSupervisor.start_child(Supervisor, InstanceProcess)
      ref = Process.monitor(pid)
      refs = Map.put(refs, ref, instance_id)
      instance_ids = Map.put(instance_ids, instance_id, pid)
      {:noreply, {instance_ids, refs}}
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

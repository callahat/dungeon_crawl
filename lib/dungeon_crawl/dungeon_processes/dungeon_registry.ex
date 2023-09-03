defmodule DungeonCrawl.DungeonProcesses.DungeonRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.{DungeonProcess}
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
  Looks up the dungeon pid for `dungeon_id` stored in `server`.

  Returns `{:ok, pid}` if the dungeon exists, `:error` otherwise
  """
  def lookup(server, dungeon_id) do
    GenServer.call(server, {:lookup, dungeon_id})
  end

  @doc """
  Looks up or creates the dungeon pid for `dungeon_id` stored in `server`.

  Returns `{:ok, pid}`.
  """
  def lookup_or_create(server, dungeon_id) do
    case lookup(server, dungeon_id) do
      :error ->
        create(server, dungeon_id)
        lookup(server, dungeon_id)

      {:ok, pid} ->
        {:ok, pid}
    end
  end

  @doc """
  Ensures there is a dungeon associated with the given `dungeon_id` in `server`.
  """
  def create(server, dungeon_id) do
    GenServer.cast(server, {:create, dungeon_id})
  end

  @doc """
  Stops the dungeon associated with the given `dungeon_id` in `server`, allowing it to be removed.
  """
  def remove(server, dungeon_id) do
    GenServer.cast(server, {:remove, dungeon_id})
  end

  @doc """
  List the dungeon ids and the dungeon processes they are associated with.
  Gives some insight into what dungeon processes are running.
  """
  def list(server) do
    GenServer.call(server, {:list})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, supervisor} = DynamicSupervisor.start_link strategy: :one_for_one
    dungeon_ids = %{}
    refs = %{}
    {:ok, {dungeon_ids, refs, supervisor}}
  end

  @impl true
  def handle_call({:lookup, dungeon_id}, _from, {dungeon_ids, _, _} = state) do
    {:reply, Map.fetch(dungeon_ids, dungeon_id), state}
  end

  @impl true
  def handle_call({:list}, _from, {dungeon_ids, _, _} = state) do
    {:reply, dungeon_ids, state}
  end

  @impl true
  def handle_cast({:create, dungeon_id}, {dungeon_ids, refs, supervisor}) do
    if Map.has_key?(dungeon_ids, dungeon_id) do
      {:noreply, {dungeon_ids, refs, supervisor}}
    else
      with di when not is_nil(di) <- DungeonInstances.get_dungeon(dungeon_id) do
        {:noreply, _create_dungeon(dungeon_id, di, {dungeon_ids, refs, supervisor})}
      else
        _error ->
          Logger.error "Got a CREATE cast for #{dungeon_id} but its already been cleared"
          {:noreply, {dungeon_ids, refs, supervisor}}
      end
    end
  end

  @impl true
  def handle_cast({:remove, dungeon_id}, {dungeon_ids, refs, supervisor}) do
    if Map.has_key?(dungeon_ids, dungeon_id), do: GenServer.stop(Map.fetch!(dungeon_ids, dungeon_id), :shutdown)
    {:noreply, {dungeon_ids, refs, supervisor}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {dungeon_ids, refs, supervisor}) do
    {dungeon_id, refs} = Map.pop(refs, ref)
    dungeon_ids = Map.delete(dungeon_ids, dungeon_id)
    {:noreply, {dungeon_ids, refs, supervisor}}
  end

  defp _create_dungeon(dungeon_id, dungeon_instance, {dungeon_ids, refs, supervisor}) do
    {:ok, map_set_process} = DynamicSupervisor.start_child(supervisor, DungeonProcess)

    dungeon = Repo.preload(dungeon_instance, :dungeon).dungeon

    author = if dungeon.user_id, do: Account.get_user(dungeon.user_id), else: %Account.User{}

    DungeonProcess.set_author(map_set_process, author)
    DungeonProcess.set_dungeon(map_set_process, dungeon)
    DungeonProcess.set_dungeon_instance(map_set_process, dungeon_instance)
    DungeonProcess.set_state_values(map_set_process, dungeon_instance.state) # todo: can state just be referenced from dungeon_instance now?
    DungeonProcess.start_scheduler(map_set_process)

    Repo.preload(dungeon_instance, :levels).levels
    |> Enum.each(fn level ->
         DungeonProcess.load_instance(map_set_process, level)
       end)

    ref = Process.monitor(map_set_process)
    refs = Map.put(refs, ref, dungeon_id)
    dungeon_ids = Map.put(dungeon_ids, dungeon_id, map_set_process)
    {dungeon_ids, refs, supervisor}
  end
end

defmodule DungeonCrawl.DungeonProcesses.DungeonRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.Account
  alias DungeonCrawl.DungeonProcesses.{DungeonProcess}
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.Horde.{DungeonSupervisor, Registry}
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
    {:ok, {}}
  end

  @impl true
  def handle_call({:lookup, dungeon_id}, _from, state) do
    result = \
      case Registry.get_dungeon_process_meta({:dungeon_id, dungeon_id}) do
        {:ok, {:pid, pid}} -> {:ok, pid}
        _error -> :error
      end
    {:reply, result, state}
  end

  @impl true
  def handle_call({:list}, _from, state) do
    # todo, this probably needs to be the meta content
    dungeon_ids =
      DungeonSupervisor.which_children
      |> Enum.map(fn {_, pid, _, _} ->
        case Registry.get_dungeon_process_meta({:pid, pid}) do
          {:ok, {_, dungeon_id}} -> {dungeon_id, pid}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    {:reply, dungeon_ids, state}
  end

  @impl true
  def handle_cast({:create, dungeon_id}, state) do
    case Registry.get_dungeon_process_meta({:dungeon_id, dungeon_id}) do
      {:ok, {:pid, _pid}} ->
        {:noreply, state}

      _error ->
        with di when not is_nil(di) <- DungeonInstances.get_dungeon(dungeon_id) do
          {:noreply, _create_dungeon(di, state)}
        else
          _error ->
            Logger.error "Got a CREATE cast for #{dungeon_id} but its already been cleared"
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_cast({:remove, dungeon_id}, state) do
    case Registry.get_dungeon_process_meta({:dungeon_id, dungeon_id}) do
      {:ok, {:pid, pid}} -> GenServer.stop(pid, :shutdown)
      _ -> nil # nothing to do/already dead?
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Registry.remove_dungeon_process_meta({:pid, pid})
    {:noreply, state}
  end

  defp _create_dungeon(dungeon_instance, state) do
    child_spec = %{
      id: dungeon_instance.id,
      start: {DungeonProcess, :start_link, [[name: _via_tuple(dungeon_instance.id)]]},
      restart: :transient, # if it dies it dies (normally)
    }

    dungeon_process =
      case DungeonSupervisor.start_child(child_spec) do
        {:ok, dungeon_process} -> dungeon_process
        {:error, {:already_started, dungeon_process}} -> dungeon_process
      end

    # Track where each process lives by dungeon instance id.
    Process.monitor(dungeon_process)
    Registry.add_dungeon_process_meta(dungeon_instance.id, dungeon_process)

    dungeon = Repo.preload(dungeon_instance, :dungeon).dungeon

    author = if dungeon.user_id, do: Account.get_user(dungeon.user_id), else: %Account.User{}

    DungeonProcess.set_author(dungeon_process, author)
    DungeonProcess.set_dungeon(dungeon_process, dungeon)
    DungeonProcess.set_dungeon_instance(dungeon_process, dungeon_instance)
    DungeonProcess.set_state_values(dungeon_process, dungeon_instance.state)
    DungeonProcess.start_scheduler(dungeon_process)

    Repo.preload(dungeon_instance, :levels).levels
    |> Enum.each(fn level ->
         DungeonProcess.load_instance(dungeon_process, level)
       end)

    state
  end

  defp _via_tuple(name) do
    {:via, Horde.Registry, {Registry, name}}
  end
end

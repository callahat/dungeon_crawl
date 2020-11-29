defmodule DungeonCrawl.DungeonProcesses.ProgramRegistry do
  use GenServer

  require Logger

  alias DungeonCrawl.DungeonProcesses.{ProgramRegistry,ProgramProcess}

  defstruct program_ids: %{},
            refs: %{},
            inverse_refs: %{},
            instance_process: nil,
            program_supervisor: nil

  ## Client API

  @doc """
  Starts the program process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Links the running instance. This will initialize all the programs and start them.
  Program IDs are map tile ids, since each map tile may have an associated program.
  """
  def link_instance(server, instance_process) do
    GenServer.call(server, {:link_instance, instance_process})
  end

  @doc """
  Loads a script which will start a program if valid. The program_id should correspond to a map_tile_id,
  and if the given program_id already has a running program, it will be replaced.
  """
  def start_program(server, program_id, script) do
    GenServer.call(server, {:start_program, program_id, script})
  end

  @doc """
  Looks up the program pid for `program_id` stored in `server`.

  Returns `{:ok, pid}` if the instance exists, `:error` otherwise
  """
  def lookup(server, program_id) do
    GenServer.call(server, {:lookup, program_id})
  end

  @doc """
  Returns a list of all the program ids.
  """
  def list_all_program_ids(server) do
    GenServer.call(server, {:list_all_program_ids})
  end

  @doc """
  Changes the id for a process. This can be used when a temporary tile has been saved
  to the DataBase. This keeps the registry id in sync with the DB id.
  """
  def change_program_id(server, old_program_id, new_program_id) do
    GenServer.call(server, {:change_program_id, old_program_id, new_program_id})
  end

  @doc """
  Returns the state of the program registry. Useful mainly with testing.
  """
  def get_state(server) do
    GenServer.call(server, {:get_state})
  end

  @doc """
  Will pause the program's cycle. The program will still exist and maintain its state, however it will
  not continue to execute instructions until resumed.
  """
  def pause_all_programs(server) do
    GenServer.cast(server, {:pause_all_programs})
  end

  @doc """
  Resumes the program's cycle.
  """
  def resume_all_programs(server) do
    GenServer.cast(server, {:resume_all_programs})
  end

  @doc """
  Stops and removes the program associated with the given id.
  """
  def stop_program(server, program_id) do
    GenServer.cast(server, {:stop_program, program_id})
  end

  @doc """
  Stops and removes all the programs, and removes the instance_process association.
  """
  def stop_all_programs(server) do
    GenServer.cast(server, {:stop_all_programs})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, program_supervisor} = DynamicSupervisor.start_link(strategy: :one_for_one)
    {:ok, %ProgramRegistry{program_supervisor: program_supervisor}}
  end

  @impl true
  def handle_call({:link_instance, instance_process}, _from, %ProgramRegistry{instance_process: nil} = program_registry) do
    registry_state = %{ program_registry | instance_process: instance_process}

    {:reply, :ok, registry_state}
  end

  @impl true
  def handle_call({:link_instance, _instance_process}, _from, registry_state) do
    {:reply, :exists, registry_state}
  end

  @impl true
  def handle_call({:start_program, program_id, script}, _from, registry_state) do
    if program_process = registry_state.program_ids[program_id] do
      ProgramProcess.end_program(program_process)
    end

    {:reply, :ok, _start_program(%{id: program_id, script: script}, registry_state)}
  end

  @impl true
  def handle_call({:lookup, program_id}, _from, registry_state) do
    {:reply, registry_state.program_ids[program_id], registry_state}
  end

  @impl true
  def handle_call({:list_all_program_ids}, _from, registry_state) do
    {:reply, Map.keys(registry_state.program_ids), registry_state}
  end

  @impl true
  def handle_call({:get_state}, _from, registry_state) do
    {:reply, registry_state, registry_state}
  end

  @impl true
  def handle_call({:change_program_id, old_program_id, new_program_id}, _from, registry_state) do
    {program_process, program_ids} = Map.pop(registry_state.program_ids, old_program_id)

    if program_process do
      {ref, inverse_refs} = Map.pop(registry_state.inverse_refs, old_program_id)
      refs = Map.delete(registry_state.refs, ref)

      refs = Map.put(refs, ref, new_program_id)
      inverse_refs = Map.put(inverse_refs, new_program_id, ref)
      program_ids = Map.put(program_ids, new_program_id, program_process)

      program_process_state = ProgramProcess.get_state(program_process)
      ProgramProcess.set_state(program_process, %{ program_process_state | map_tile_id: new_program_id })

      {:reply, :ok, %{ registry_state | program_ids: program_ids, refs: refs, inverse_refs: inverse_refs }}
    else
      {:reply, :ok, registry_state}
    end
  end

  @impl true
  def handle_cast({:pause_all_programs}, registry_state) do
    registry_state.program_ids
    |> Map.to_list
    |> Enum.each(fn {_pid, process} -> ProgramProcess.stop_scheduler(process) end)

    {:noreply, registry_state}
  end

  @impl true
  def handle_cast({:resume_all_programs}, registry_state) do
    registry_state.program_ids
    |> Map.to_list
    |> Enum.each(fn {_pid, process} -> ProgramProcess.start_scheduler(process) end)

    {:noreply, registry_state}
  end

  @impl true
  def handle_cast({:stop_program, program_id}, registry_state) do
    if program_process = registry_state.program_ids[program_id] do
      ProgramProcess.end_program(program_process)
    end
    {:noreply, registry_state}
  end

  @impl true
  def handle_cast({:stop_all_programs}, registry_state) do
    registry_state.program_ids
    |> Map.to_list
    |> Enum.each(fn {_pid, process} -> GenServer.stop(process, :shutdown) end)

    {:noreply, %{ registry_state | instance_process: nil }}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, registry_state) do
    {program_id, refs} = Map.pop(registry_state.refs, ref)
    inverse_refs = Map.delete(registry_state.inverse_refs, program_id)
    program_ids = if pid == registry_state.program_ids[program_id],
                    do: Map.delete(registry_state.program_ids, program_id),
                    else: registry_state.program_ids
    {:noreply, %{ registry_state | program_ids: program_ids, refs: refs, inverse_refs: inverse_refs }}
  end

  defp _start_program(map_tile, registry_state) do
    {:ok, program_process} = DynamicSupervisor.start_child(registry_state.program_supervisor, ProgramProcess)

    ref = Process.monitor(program_process)
    refs = Map.put(registry_state.refs, ref, map_tile.id)
    inverse_refs = Map.put(registry_state.inverse_refs, map_tile.id, ref)
    program_ids = Map.put(registry_state.program_ids, map_tile.id, program_process)

    ProgramProcess.start_scheduler(program_process)

    ProgramProcess.initialize_program(program_process, registry_state.instance_process, map_tile.id, map_tile.script)

    %{ registry_state | program_ids: program_ids, refs: refs, inverse_refs: inverse_refs }
  end
end

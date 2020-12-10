defmodule Test.ProgramProcess do
  use GenServer, restart: :temporary

  require Logger

  @timeout 100

  ## Client API

  @doc """
  Starts the instance process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Updates the given map_tile.
  """
  def set_initial_state(program, program_id, elixir_commands) do
    GenServer.call(program, {:set_initial_state, {program_id, elixir_commands}})
  end

  @doc """
  Starts the scheduler
  """
  def start_scheduler(instance) do
    Process.send_after(instance, :perform_actions, @timeout)
  end

  @doc """
  echo a message
  """
  def message(program, message) do
    GenServer.cast(program, {:message, {message}})
  end


  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, %{pc: 0, commands: [], program_id: nil}}
  end

  @impl true
  def handle_call({:set_initial_state, {program_id, commands}}, _from, %{} = state) do
    {:reply, :ok, %{pc: 0, commands: commands, program_id: program_id}}
  end

  @impl true
  def handle_cast({:message, {message}}, %{} = state) do
    IO.puts "Program #{state.program_id} got a cast message"
    IO.inspect message
    {:noreply, state}
  end

  def handle_info(:perform_actions, state) do
    start_ms = :os.system_time(:millisecond)
    IO.puts inspect Enum.at(state.commands, state.pc)
    state = if command = Enum.at(state.commands, state.pc) do
              IO.puts "command:"
              IO.inspect command
              [module, function, params] = command
              IO.inspect apply(module, function, params)
              %{ state | pc: state.pc + 1 }
            else
              %{ state | pc: 0 }
            end

    elapsed_ms = :os.system_time(:millisecond) - start_ms
    IO.puts "perform_actions for program # #{state.program_id} took #{(:os.system_time(:millisecond) - start_ms)} ms"

    Process.send_after(self(), :perform_actions, @timeout)

    {:noreply, state}
  end

end

defmodule Test.ProgramRegistry do
  use GenServer, restart: :temporary

  require Logger

  ## Client API

  @doc """
  Starts the program process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def start_program(server, program_id, elixir_commands) do
    GenServer.call(server, {:create, program_id, elixir_commands})
  end

  def send_program_message(server, program_id, message) do
    GenServer.call(server, {:send_message, program_id, message})
  end

  def stop_all_programs(server) do
    GenServer.cast(server, {:stop_all_programs})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    program_ids = %{}
    refs = %{}
    {:ok, {program_ids, refs}}
  end

  # These first two are really to make test setup more convenient
  @impl true
  def handle_call({:create, program_id, elixir_commands}, _from, {program_ids, refs}) do
    {:ok, program_process} = DynamicSupervisor.start_child(DungeonCrawl.DungeonProcesses.Supervisor, Test.ProgramProcess)

    ref = Process.monitor(program_process)
    refs = Map.put(refs, ref, program_id)
    program_ids = Map.put(program_ids, program_id, program_process)

    Test.ProgramProcess.set_initial_state(program_process, program_id, elixir_commands)
    Test.ProgramProcess.start_scheduler(program_process)

    {:reply, program_id, {program_ids, refs}}
  end

  @impl true
  def handle_call({:send_message, program_id, message}, _from, {program_ids, _refs} = state) do
    case program_ids[program_id] do
      nil -> nil
      program -> Test.ProgramProcess.message(program, message)
    end

    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:stop_all_programs}, {program_ids, refs}) do
    program_ids
    |> Map.to_list
    |> Enum.each(fn {_pid, process} -> GenServer.stop(process, :shutdown) end)

    {:noreply, {program_ids, refs}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, {program_ids, refs}) do
    {program_id, refs} = Map.pop(refs, ref)
    program_ids = Map.delete(program_ids, program_id)
    {:noreply, {program_ids, refs}}
  end
end
"""
c "perf2.exs"
{:ok, registry} = Test.ProgramRegistry.start_link([])
Test.ProgramRegistry.start_program(registry, 1, [[String, :length, ["EGGERE"]], [:timer, :sleep, [10000]]])
Test.ProgramRegistry.send_program_message(registry, 1, "HEY DID YOU GET THIS")
Test.ProgramRegistry.stop_all_programs(registry)
"""

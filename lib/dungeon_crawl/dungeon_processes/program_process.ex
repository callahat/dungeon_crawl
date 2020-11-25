defmodule DungeonCrawl.DungeonProcesses.ProgramProcess do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Scripting.Runner

  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.ProgramProcess

  defstruct instance_process: nil,
            active: false,
            program: %Program{},
            map_tile_id: nil,
            timer_ref: nil

  ## Client API

  @timeout 50

  @doc """
  Starts the program process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @doc """
  Parses and loads the script into the program process.
  """
  def initialize_program(program_process, instance_process, map_tile_id, script) do
    GenServer.cast(program_process, {:initialize_program, {instance_process, map_tile_id, script}})
  end

  @doc """
  Inspect the state. Mainly a test convenience function.
  """
  def get_state(program_process) do
    GenServer.call(program_process, {:get_state})
  end

  @doc """
  Set the state. Mainly a test convenience function.
  """
  def set_state(program_process, %ProgramProcess{} = state) do
    GenServer.call(program_process, {:set_state, state})
  end

  @doc """
  Returns a boolean indicating wether or not the program has a matching label
  for the given event.
  """
  def responds_to_event?(program_process, event) do
    GenServer.call(program_process, {:responds_to_event?, event})
  end

  @doc """
  Sends an event to the program.
  """
  def send_event(program_process, event, sender) do
    GenServer.cast(program_process, {:send_event, {event, sender}})
  end

  @doc """
  Starts the scheduler
  """
  def start_scheduler(program_process) do
    GenServer.call(program_process, {:start_scheduler})
  end

  @doc """
  Stops the scheduler
  """
  def stop_scheduler(program_process) do
    GenServer.call(program_process, {:stop_scheduler})
  end

  ## Defining GenServer Callbacks

  @impl true
  def init(:ok) do
    {:ok, %ProgramProcess{}}
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:set_state, new_state}, _from, _state) do
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:responds_to_event?, event}, _from, %ProgramProcess{program: program} = state) do
    {:reply, !! Program.line_for(program, event), state}
  end

  @impl true
  def handle_call({:start_scheduler}, _from, %ProgramProcess{timer_ref: nil} = state) do
    timer_ref = Process.send_after(self(), :perform_actions, @timeout)
    {:reply, :started, %{ state | timer_ref: timer_ref, active: true }}
  end

  @impl true
  def handle_call({:start_scheduler}, _from, state) do
    {:reply, :exists, state}
  end

  @impl true
  def handle_call({:stop_scheduler}, _from, %ProgramProcess{timer_ref: timer_ref} = state) do
    timer_ref && Process.cancel_timer(timer_ref)
    {:reply, :started, %{ state | timer_ref: nil, active: false }}
  end

  @impl true
  def handle_cast({:initialize_program, {instance_process, map_tile_id, script}}, state) do
    case _parse_program(script) do
      {:ok, program} ->
        program = %{ program | broadcasts: state.program.broadcasts, responses: state.program.responses }
        {:noreply, %ProgramProcess{instance_process: instance_process, active: true, program: program, map_tile_id: map_tile_id}}
      {:none} ->        {:stop, :normal, state}
      _ ->              {:stop, :normal, state}
    end
  end

  @impl true
  def handle_cast({:send_event, {event, sender}}, %ProgramProcess{program: program, timer_ref: timer_ref} = state) do
    with false <- program.locked,
         next_pc when not(is_nil(next_pc)) <- Program.line_for(program, event),
         program <- %{program | pc: next_pc, lc: 0, status: :alive, event_sender: sender} do

      if timer_ref && Process.read_timer(timer_ref), do: Process.cancel_timer(timer_ref)

      program = _run_commands(%{ state | program: program, timer_ref: nil })

      timer_ref = Process.send_after(self(), :perform_actions, @timeout)

      {:noreply, %{ state | program: program, timer_ref: timer_ref }}
    else
      nil ->
        InstanceProcess.send_standard_behavior(state.instance_process, state.map_tile_id, event, sender)
        {:noreply, state}
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:perform_actions, %ProgramProcess{active: false} = state) do
    # not active, so do not perform actions and do not reschedule
    {:noreply, state}
  end

  @impl true
  def handle_info(:perform_actions, %ProgramProcess{instance_process: _instance_process, program: _program} = state) do
    program = _run_commands(state)

    timer_ref = Process.send_after(self(), :perform_actions, @timeout)

    {:noreply, %{ state | program: program, timer_ref: timer_ref }}
  end

  defp _parse_program(script) do
    case Scripting.Parser.parse(script) do
     {:ok, program} ->
       unless program.status == :dead do
         {:ok, program}
       else
         {:none}
       end
     other ->
       Logger.warn """
                   Possible corrupt script for map tile instance: #{inspect script}
                   Not :ok response: #{inspect other}
                   """
       {:invalid}
    end
  end

  defp _run_commands(%ProgramProcess{instance_process: instance_process, program: program, map_tile_id: map_tile_id}) do
    # for now, just run in a run_with block. This can be refactored later and pushed further into the command module
    #   where the instance is grabbed only for those commands that need to query, set, or do something with the instance
    # probbly should have this return the program
# TODO: refactor out the run_with block, its causign deadlocks.
IO.puts "deadlock or somethin? #{map_tile_id} #{inspect instance_process}"
    program = \
    InstanceProcess.run_with(instance_process, fn instance_state ->
IO.puts "in the run wit"
      runner_state = %Runner{program: program, object_id: map_tile_id, state: instance_state, event_sender: program.event_sender, instance_process: instance_process}
IO.puts "Runner"
      %{program: program, state: instance_state} = Scripting.Runner.run(runner_state)
                                                   |> Instances.handle_broadcasting() # any nontile_update broadcasts left
IO.puts "runner done"
      {program, instance_state}
    end)
IO.puts "wraped up with the run command? #{map_tile_id} #{inspect instance_process}"
   program
  end
end


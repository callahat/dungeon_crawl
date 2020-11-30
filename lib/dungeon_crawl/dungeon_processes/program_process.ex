defmodule DungeonCrawl.DungeonProcesses.ProgramProcess do
  use GenServer, restart: :temporary

  require Logger

  alias DungeonCrawl.Scripting
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Scripting.Runner

  alias DungeonCrawl.DungeonProcesses.InstanceProcess
  alias DungeonCrawl.DungeonProcesses.ProgramProcess

  defstruct instance_process: nil,
            active: false,
            program: %Program{},
            map_tile_id: nil,
            timer_ref: nil,
            event_sender: nil

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
  Ends the program. This is useful when the current program for a tile is replaced by a different program.
  """
  def end_program(program_process) do
    GenServer.cast(program_process, {:end_program})
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
        object = InstanceProcess.get_tile(instance_process, map_tile_id) || %{parsed_state: %{}}
        program = %{ program | responses: state.program.responses, wait_cycles: object.parsed_state[:wait_cycles] || 5 }
        {:noreply, %ProgramProcess{instance_process: instance_process, active: true, program: program, map_tile_id: map_tile_id}}
      {:none} ->        {:stop, :normal, state}
      _ ->              {:stop, :normal, state}
    end
  end

  @impl true
  def handle_cast({:end_program}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_cast({:send_event, {event, sender}}, %ProgramProcess{program: program, timer_ref: timer_ref} = state) do
    with false <- program.locked,
         next_pc when not(is_nil(next_pc)) <- Program.line_for(program, event),
         program <- %{program | pc: next_pc, lc: 0, status: :alive} do

      if timer_ref && Process.read_timer(timer_ref), do: Process.cancel_timer(timer_ref)

      _run_commands(%{ state | program: program, timer_ref: nil, event_sender: sender})
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
    _run_commands(state)
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

  defp _run_commands(%ProgramProcess{} = state) do
    runner_state = %Runner{program: state.program,
                           object_id: state.map_tile_id,
                           event_sender: state.event_sender,
                           instance_process: state.instance_process}
    %{program: program} = Scripting.Runner.run(runner_state)
                          |> _handle_broadcasting()

    case program.status do
      :idle ->
        {:noreply, %{ state | program: program }}

      :dead ->
        {:stop, :normal, %{ state | program: program }}

      _alive ->
        timer_ref = Process.send_after(self(), :perform_actions, program.wait_cycles * @timeout)
        {:noreply, %{ state | program: program, timer_ref: timer_ref }}
    end
  end

  def _handle_broadcasting(runner_context) do
    _handle_broadcasts(Enum.reverse(runner_context.program.responses), runner_context.event_sender)
    %{ runner_context | program: %{ runner_context.program | responses: [] } }
  end

  defp _handle_broadcasts([], _), do: nil
  defp _handle_broadcasts([{type, payload} | messages], player_location = %DungeonCrawl.Player.Location{}) do
    DungeonCrawlWeb.Endpoint.broadcast "players:#{player_location.id}", type, payload
    _handle_broadcasts(messages, player_location)
  end
  defp _handle_broadcasts([_ | messages], sender), do: _handle_broadcasts(messages, sender)
end


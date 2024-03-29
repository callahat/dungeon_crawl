defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonProcesses.Levels
  alias DungeonCrawl.StateValue

  defstruct program: %Program{}, object_id: nil, state: %Levels{}, event_sender: nil, msg_count: 0

require Logger
  @doc """
  Run the program one cycle. Returns the next state of the program.
  One cycle being until it hits a stop or wait condition.
  If a label/message is given as a param, the given label will have
  first priority for updating the pc and executing the script from
  there.
  """
  def run(%Runner{program: program, object_id: object_id, state: state} = runner_state, label) do
    with object when not(is_nil(object)) <- Levels.get_tile_by_id(state, %{id: object_id}),
         false <- StateValue.get_bool(object, "locked"),
         next_pc when not(is_nil(next_pc)) <- Program.line_for(program, label),
         program <- %{program | pc: next_pc, lc: 0, status: :alive} do
      _run(%Runner{ runner_state | program: program})
    else
      _ ->
        runner_state
    end
  end

  def run(%Runner{program: program, object_id: object_id, state: state, msg_count: msg_count} = runner_state) do
    runner_state =
      if program.timed_messages != [] do
        {triggered, timed_messages} = Enum.split_with(program.timed_messages, fn {trigger_time, _label, _} ->
          DateTime.compare(DateTime.utc_now, trigger_time) != :lt
        end)
        triggered = Enum.map(triggered, fn {_, message, sender} -> {message, sender} end)
        %{ runner_state | program: %{ program | messages: program.messages ++ triggered, timed_messages: timed_messages}}
      else
        runner_state
      end

    cond do
      program.messages == [] || program.status == :alive || program.status == :dead ->
        # todo: maybe have the check for active tile live elsewhere
        if Levels.get_tile_by_id(state, %{id: object_id}) do
          _run(runner_state)
        else
          runner_state
        end

      program.messages != [] && msg_count < 5 -> # a break to force bad scripts/infinite send loops from locking the instance indefinitely
        [{label, sender} | messages ] = program.messages
        if Program.line_for(program, label) do
          run(%{ runner_state | event_sender: sender, program: %{ program | messages: messages }, msg_count: msg_count+1}, label)
        else
          # discard the unrespondable message
          run(%{ runner_state | event_sender: sender, program: %{ program | messages: messages }, msg_count: msg_count+1})
        end

      true -> runner_state
    end
  end

  def _run(%Runner{program: program, object_id: object_id, state: state} = runner_state) do
    object = Levels.get_tile_by_id(state, %{id: object_id})
    case program.status do
      :alive ->
        [command, params] = program.instructions[program.pc]
# Logging is expensive, comment/remove later
if System.get_env("SHOW_RUNNER_COMMANDS") == "true" do
# coveralls-ignore-start
Logger.info "*******************************************Running:***************************************************"
Logger.info "Line: #{program.pc}"
Logger.info inspect object_id
Logger.info inspect command
Logger.info inspect params
Logger.info inspect object
if object, do: Logger.info inspect object.state
Logger.info "event sender:"
Logger.info inspect runner_state.event_sender
Logger.info "instance state:"
Logger.info inspect state.state_values
Logger.info "msg_count: " <> inspect(runner_state.msg_count)
Logger.info inspect program.timed_messages
Logger.info inspect program.messages
# coveralls-ignore-stop
end

        runner_state = apply(Command, command, [runner_state, params])

        # increment program counter, check for end of program
        program = %{runner_state.program | pc: runner_state.program.pc + 1}
        if program.pc > Enum.count(program.instructions) do
          run( %{ runner_state | program: %{program | pc: 0, status: :idle} } )
        else
          run( %{ runner_state | program: program } )
        end

      :wait ->
        wait_cycles = program.wait_cycles - 1
        status = if wait_cycles <= 0, do: :alive, else: program.status
        %{ runner_state | program: %{program | wait_cycles: wait_cycles, status: status} }

      :idle ->
        runner_state

      :dead ->
        runner_state
    end
  end
end

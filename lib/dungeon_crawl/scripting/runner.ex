defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.StateValue

  defstruct program: %Program{}, object_id: nil, state: %Instances{}, event_sender: nil, msg_count: 0, instance_process: nil

require Logger
  @doc """
  Run the program one cycle. Returns the next state of the program.
  One cycle being until it hits a stop or wait condition.
  If a label/message is given as a param, the given label will have
  first priority for updating the pc and executing the script from
  there.
  """
  # Label will be unused due to usign build in otp messaging sending instead
  def run(%Runner{program: program, object_id: object_id, state: state} = runner_state, label) do
    with object when not(is_nil(object)) <- Instances.get_map_tile_by_id(state, %{id: object_id}),
         false <- StateValue.get_bool(object, :locked),
         next_pc when not(is_nil(next_pc)) <- Program.line_for(program, label),
         program <- %{program | pc: next_pc, lc: 0, status: :alive} do
      _run(%Runner{ runner_state | program: program})
    else
      _ ->
        runner_state
    end
  end

  def run(%Runner{object_id: object_id, state: state} = runner_state) do
IO.puts "RUN"
    # might still want to add a cycle breaker to keep a process from an infinite loop without waiting
    if Instances.get_map_tile_by_id(state, %{id: object_id}) do
      _run(runner_state)
    else
      runner_state
    end
#    cond do
#      program.status == :alive || program.status == :dead ->
#        # todo: maybe have the check for active tile live elsewhere
#        if Instances.get_map_tile_by_id(state, %{id: object_id}) do
#          _run(runner_state)
#        else
#          runner_state
#        end
#
#      program.messages != [] && msg_count < 5 -> # a break to force bad scripts/infinite send loops from locking the instance indefinitely
#        [{label, sender} | messages ] = program.messages
#        if Program.line_for(program, label) do
#          run(%{ runner_state | event_sender: sender, program: %{ program | messages: messages }, msg_count: msg_count+1}, label)
#        else
#          # discard the unrespondable message
#          run(%{ runner_state | event_sender: sender, program: %{ program | messages: messages }, msg_count: msg_count+1})
#        end
#
#      true -> runner_state
#    end
  end

  def _run(%Runner{program: program, object_id: object_id, state: state} = runner_state) do
    case program.status do
      :alive ->
        [command, params] = program.instructions[program.pc]
# Logging is expensive, comment/remove later
if true || System.get_env("SHOW_RUNNER_COMMANDS") == "true" do
object = Instances.get_map_tile_by_id(state, %{id: object_id})
Logger.info "*******************************************Running:***************************************************"
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

defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonProcesses.Instances
  alias DungeonCrawl.DungeonProcesses.InstanceProcess

  defstruct program: %Program{},
            object_id: nil,
            event_sender: nil,
            msg_count: 0,
            instance_process: nil

require Logger
  @doc """
  Run the program one cycle. Returns the next state of the program.
  One cycle being until it hits a stop or wait condition.
  """
  def run(%Runner{object_id: object_id, program: program} = runner_state) do
    # might still want to add a cycle breaker to keep a process from an infinite loop without waiting
    if InstanceProcess.get_tile(runner_state.instance_process, object_id) do
      _run(runner_state)
    else
      %{ runner_state | program: %{ program | status: :dead } }
    end
  end

  def _run(%Runner{program: program, object_id: object_id} = runner_state) do
    case program.status do
      :alive ->
        [command, params] = program.instructions[program.pc]
# Logging is expensive, comment/remove later
if System.get_env("SHOW_RUNNER_COMMANDS") == "true" do
state = InstanceProcess.get_state(runner_state.instance_process)
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
        program = %{ runner_state.program | pc: runner_state.program.pc + 1 }
        if program.pc > Enum.count(program.instructions) do
          run( %{ runner_state | program: %{program | pc: 0, status: :idle} } )
        else
          run( %{ runner_state | program: program } )
        end

      :wait ->
        %{ runner_state | program: %{ program | status: :alive } }

      :idle ->
        runner_state

      :dead ->
        runner_state
    end
  end
end

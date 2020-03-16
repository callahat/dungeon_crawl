defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Runner
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.DungeonProcesses.Instances

  defstruct program: %Program{}, object: %{}, state: %Instances{}, event_sender: nil

require Logger
  @doc """
  Run the program one cycle. Returns the next state of the program.
  One cycle being until it hits a stop or wait condition.
  """
  def run(runner_state = %Runner{program: program}, label) do
    with next_pc when not(is_nil(next_pc)) <- Program.line_for(program, label),
         program = %{program | pc: next_pc, lc: 0, status: :alive} do
      run(%Runner{ runner_state | program: program})
    else
      _ ->
        runner_state
    end
  end

  def run(%Runner{program: program, object: object} = runner_state) do
    case program.status do
      :alive ->
        [command, params] = program.instructions[program.pc]
Logger.info "Running:"
Logger.info inspect command
Logger.info inspect params
Logger.info inspect object
Logger.info inspect object.state
Logger.info inspect object && object.state
        runner_state = apply(Command, command, [runner_state, params])

        # increment program counter, check for end of program
        program = %{runner_state.program | pc: runner_state.program.pc + 1}
        if program.pc > Enum.count(program.instructions) do
          %{ runner_state | program: %{program | pc: 0, status: :idle} }
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

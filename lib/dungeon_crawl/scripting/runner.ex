defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Command

require Logger
  @doc """
  Run the program one cycle. Returns the next state of the program.
  One cycle being until it hits a stop or wait condition.
  """
  def run(%{program: program, object: object, label: label}) do
    with [[next_pc, _]] <- program.labels[label] || [] |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1),
         program = %{program | pc: next_pc, status: :alive} do
      run(%{program: program, object: object})
    else
      _ ->
        %{program: %{program | responses: [ "Label not in script: #{label}" | program.responses]}, object: object}
    end
  end

  def run(%{program: program, object: object}) do
    case program.status do
      :alive ->
        [command, params] = program.instructions[program.pc]
Logger.info "Running:"
Logger.info inspect command
Logger.info inspect params
Logger.info inspect object.state
        %{program: program, object: object} = apply(Command, command, [%{program: program, object: object, params: params}])

        # increment program counter, check for end of program
        program = %{program | pc: program.pc + 1}
        if program.pc > Enum.count(program.instructions) do
          %{program: %{program | pc: 0, status: :idle}, object: object}
        else
          run(%{program: program, object: object})
        end

      :wait ->
        wait_cycles = program.wait_cycles - 1
        status = if wait_cycles <= 0, do: :alive, else: program.status
        %{program: %{program | wait_cycles: wait_cycles, status: status}, object: object}

      :idle ->
        %{program: program, object: object}

      :dead ->
        %{program: program, object: object}
    end
  end
end

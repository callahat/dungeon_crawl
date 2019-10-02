defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Command

require Logger
  @doc """
  Run the program until encountering a stop marker. Returns the final state of the program.
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
          # for now keep running, later just return program state
          run(%{program: program, object: object})
        end

      :idle ->
        %{program: program, object: object}

      :dead ->
        %{program: program, object: object}
    end
  end
end

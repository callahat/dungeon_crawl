defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Program

  @doc """
  Run the program until encountering a stop marker. Returns the final state of the program.
  """
  def run(%{program: program, object: object, label: label, socket: socket}) do
    with [[next_pc, _]] <- program.labels[label] |> Enum.filter(fn([l,a]) -> a end) |> Enum.take(1),
         program = %{program | pc: next_pc} do
      run(%{program: program, object: object, socket: socket})
    else
      _ -> run(%{program: program, object: object, socket: socket})
    end
  end

  def run(%{program: program, object: object, socket: socket}) do
    case program.status do
      :alive ->
        [command, params] = program.intructions[program.pc]
        # TODO: this case may get its own module later as the number of commands grow
        program = case command do
          :noop ->
            program

          :become ->
            # TODO: make this more generic
            door = Dungeon.update_map_tile!(object, Map.take(params, [:character, :color, :background_color, :state, :script]))
            broadcast socket, "door_changed", %{door_location: %{row: door.row, col: door.col, map_tile: door}
            program

          :jump_if ->
            [[neg, _command, var, op, value], label] = params
            check = case op do
                      "!=" -> object.state[var] != value
                      "==" -> object.state[var] == value
                      "<=" -> object.state[var] <= value
                      ">=" -> object.state[var] >= value
                      "<"  -> object.state[var] <  value
                      ">"  -> object.state[var] >  value
                    end
           if if(neg == "!", do: !check, else: check) do
             # first active matching label
             with [[line_number, _]] <- object.labels[label] |> Enum.filter(fn([l,a]) -> !a end) |> Enum.take(1) do
               %{program | pc: line_number}
             else
               # no valid label to jump to
               [] -> program
             end
           else
             program
           end

          :end_script ->
            %{program | status: :idle, pc: 0}
            
          :text ->
            if params != [""] do
              # TODO: probably allow this to be refined by whomever the message is for
              broadcast socket, "shout", Enum.join(params, "\n")
            end
            program
        end
        # increment program counter, check for end of program
        program = %{program | pc: program.pc + 1}
        if program.pc > Enum.count(program.instructions) do
          %{program | pc: 0, status: :idle}
        else
          # for now keep running, later just return program state
          run(%{program: program, object: object, socket: socket})
        end

      :idle ->
        %{program: program}

      :dead ->
        %{program: nil}
    end
  end

  defp broadcast(socket, event, payload) do
    DungeonCrawlWeb.Endpoint.broadcast! socket, event, payload
  end
end

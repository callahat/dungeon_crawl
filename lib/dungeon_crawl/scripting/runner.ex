defmodule DungeonCrawl.Scripting.Runner do
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.TileState
require Logger
  @doc """
  Run the program until encountering a stop marker. Returns the final state of the program.
  """
  def run(%{program: program, object: object, label: label}) do
    with [[next_pc, _]] <- program.labels[label] || [] |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1),
         program = %{program | pc: next_pc} do
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
        # TODO: this case may get its own module later as the number of commands grow
        {program, object} = case command do
          :noop ->
            {program, object}

          :become ->
            # TODO: make this more generic
            door = DungeonCrawl.DungeonInstances.update_map_tile!(object, apply(Map, :take, params ++ [[:character, :color, :background_color, :state, :script, :tile_template_id]]))
            message = ["tile_changes",
                       %{tiles: [
                           Map.put(Map.take(door, [:row, :col]), :rendering, DungeonCrawlWeb.SharedView.tile_and_style(door))
                       ]}]

            { %{program | broadcasts: [message | program.broadcasts] }, door}

          :if ->
            {:ok, object_state} = DungeonCrawl.TileState.Parser.parse(object.state)
            [[neg, _command, var, op, value], label] = params
            check = case op do
                      "!=" -> object_state[var] != value
                      "==" -> object_state[var] == value
                      "<=" -> object_state[var] <= value
                      ">=" -> object_state[var] >= value
                      "<"  -> object_state[var] <  value
                      ">"  -> object_state[var] >  value
                      _    -> !!object_state[var]
                    end

           if if(neg == "!", do: !check, else: check) do
             # first active matching label
             with [[line_number, _]] <- program.labels[label] |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1) do
               {%{program | pc: line_number}, object}
             else
               # no valid label to jump to
               [] -> {program, object}
             end
           else
             {program, object}
           end

          :end ->
            {%{program | status: :idle, pc: -1}, object}

          :text ->
            if params != [""] do
              # TODO: probably allow this to be refined by whomever the message is for
              message = Enum.map(params, fn(param) -> String.trim(param) end) |> Enum.join("\n")
              {%{program | responses: [ message | program.responses] }, object}
            else
              {program, object}
            end

          :change_state ->
            {:ok, state} = TileState.Parser.parse(object.state)
            [var, op, value] = params
            new_val = case op do
                        "++" -> state[var] + 1
                        "--" -> state[var] - 1
                        "="  -> value
                        "+=" -> state[var] + value
                        "-=" -> state[var] - value
                        "/=" -> state[var] / value
                        "*=" -> state[var] * value
                      end
            state = Map.put(state, var, new_val) |> TileState.Parser.stringify

            {program, DungeonCrawl.DungeonInstances.update_map_tile!(object, %{state: state})}

          :die ->
            object = DungeonCrawl.DungeonInstances.update_map_tile!(object, %{script: ""})
            {%{program | status: :dead, pc: -1}, object}
        end
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

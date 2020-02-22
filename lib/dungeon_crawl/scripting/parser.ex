defmodule DungeonCrawl.Scripting.Parser do
  alias DungeonCrawl.Scripting.Command
  alias DungeonCrawl.Scripting.Program

  @doc """
  Parses a valid object script into a valid set of instructions,
  or returns an error tuple if the given script is not valid.

  A script can be empty, in which case it will do nothing.
  It may also be one or more lines, each line having a character prefix
  indicating what it is (WIP - this might change as the prefix
  may not really be needed except for certain cases, such as to 
  indicate a label.)

  Two prefixes currently supported

  : - label, used for program flow; it is where the program counter will
             jump when a message is sent, the following are events sent by
             the system

  :open
  :close

  # - command, ie
  #become <kwargs>

  #if <condition>, <label>

  #end - stops the program until it receives a message that it can process.

  <no prefix> - this is treated as text that can be displayed to a player.

  ## Examples

    iex> Parser.parse(~s/#become character: 4/)
    {:ok, %Program{broadcasts: [], instructions: %{1 => [:become, [%{character: 4}]]}, labels: %{}, locked: false, pc: 1, responses: [], status: :alive}}

    iex> Parser.parse(~s/#fakecommand/)
    {:error, "Unknown command: `fakecommand`", %Program{}}
  """
  def parse(nil), do: {:ok, %Program{}}
  def parse(""),  do: {:ok, %Program{}}
  def parse(script_string) do
    case _parse_script(String.split(String.replace_trailing(script_string, "\n", ""), "\n"), %Program{}) do
      {:ok, program} ->
        {:ok, %{program | status: :alive } }

      error -> error
    end
  end

  defp _parse_script([], program), do: {:ok, program}
  defp _parse_script([line | lines], program) do
    case _parse_line(line, program) do
      {:ok, program} -> _parse_script(lines, program)

      error -> error
    end
  end

  defp _parse_line(line, program) do
    case Regex.named_captures(~r/^(?<type>#|:|@|\/|\?)(?<instruction>.*)$/, line) do
      %{"type" => "/", "instruction" => _command} ->
        _parse_shorthand_movement(line, program)

      %{"type" => "?", "instruction" => _command} ->
        _parse_shorthand_movement(line, program)

      %{"type" => "#", "instruction" => command} ->
        _parse_command(command, program)

      %{"type" => ":", "instruction" => label} ->
        _parse_label(label, program)

      %{"type" => "@", "instruction" => state_element} ->
        _parse_state_change(state_element, program)

      _ -> # If the last item in the program is also text, concat the two
        _handle_text(line, program)
    end
  end

  defp _parse_shorthand_movement(line, program) do
    with steps <- line |> String.to_charlist |> Enum.chunk_every(2),
         {:ok, expanded_steps} <- _parse_shorthand_movements(steps),
         line_number <- Enum.count(program.instructions) + 1 do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:compound_move, expanded_steps]) } }
    else
      {:error, msg} -> {:error, msg, program}
      _             -> {:error, "Invalid command: `#{line}`", program} # Probably won't hit this
    end
  end

  defp _parse_shorthand_movements([]), do: {:ok, []}
  defp _parse_shorthand_movements([ [leading_character, direction] | steps ]) do
    with {:ok, retry_until_successful} <- _parse_shorthand_directive(leading_character),
         {:ok, parsed_direction} <- _parse_shorthand_direction(direction),
         {:ok, parsed_shorthand_movements} <- _parse_shorthand_movements(steps) do
      {:ok, [ {parsed_direction, retry_until_successful} | parsed_shorthand_movements]}
    else
      {:error, msg} -> {:error, msg}
      _ -> {:error, "Invalid shorthand movement: #{[leading_character, direction]}"}
    end
  end

  defp _parse_shorthand_directive(?/), do: {:ok, true}
  defp _parse_shorthand_directive(??),  do: {:ok, false}
  defp _parse_shorthand_directive(_),   do: {:error}

  defp _parse_shorthand_direction(direction) do
    case direction do
      ?n -> {:ok, "north"}
      ?N -> {:ok, "north"}
      ?s -> {:ok, "south"}
      ?S -> {:ok, "south"}
      ?e -> {:ok, "east"}
      ?E -> {:ok, "east"}
      ?w -> {:ok, "west"}
      ?W -> {:ok, "west"}
      ?i -> {:ok, "idle"}
      ?I -> {:ok, "idle"}
      _  -> {:error}
    end
  end

  defp _parse_command(line, program) do
    with %{"command" => command} <- match = Regex.named_captures(~r/\A(?<command>[^ ]+?)(?: (?<params>.+))?\z/i, line),
         params <- _parse_params(match["params"]),
         line_number <- Enum.count(program.instructions) + 1,
         {:ok, sendable_command} <- _sendable_command(command) do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [sendable_command, params]) } }
    else
      {:error, msg} -> {:error, msg, program}
      _             -> {:error, "Invalid command: `#{line}`", program}
    end
  end

  defp _parse_label(line, program) do
    with %{"label" => label} <- Regex.named_captures(~r/\A(?<label>[A-Z\d_]+)\z/i, String.trim(line)),
         line_number <- Enum.count(program.instructions) + 1,
         existing_labels <- program.labels[label] || [],
         updated_labels <- existing_labels ++ [[line_number, true]] do
      # No need to add the label; its a noop anyway
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:noop, line]), 
                        labels: Map.put(program.labels, label, updated_labels)}}
    else
      _ ->
        {:error, "Invalid label: `#{String.trim(line)}`", program}
    end
  end

  defp _parse_state_change(element, program) do
    with state_element <- String.trim(String.downcase(element)),
         %{"element" => element, "setting" => setting} <- Regex.named_captures(~r/\A(?<element>[a-z_]+)(?<setting>.+)\z/i, state_element),
         element = String.to_atom(element),
         {:ok, op, value} <- _parse_state_setting(setting),
         line_number <- Enum.count(program.instructions) + 1 do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:change_state, [element, op, value]]) } }
    else
      nil               -> {:error, "Invalid state setting: `#{element}`", program}
      {:error, message} -> {:error, message, program}
    end
  end

  defp _parse_state_setting(setting) do
    with %{"op" => op, "value" => value} <- Regex.named_captures(~r/(?<op>\+\+|--|(?:\+|-|\*|\/)?=)\s*(?<value>.*)/, String.trim(setting)) do
      {:ok, op, _cast_param(value)}
    else
      _ -> {:error, "Invalid state assignment: `#{setting}`"}
    end
  end

  defp _handle_text(text, program) do
    # TODO: might make more sense to roll up multiline text commands in the runner to keep parsing errors able to get the right line number
    #with line_number = Enum.count(program.instructions),
    #     [:text, preceeding_text] <- program.instructions[line_number] do
    #  {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:text, preceeding_text ++ [text] ]) } }
    #else
    #  _ ->
        line_number = Enum.count(program.instructions) + 1
        {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:text, [text] ]) } }
    #end
  end

  defp _sendable_command(command) do
    if script_command = Command.get_command(command) do
      {:ok, script_command}
    else
      {:error, "Unknown command: `#{command}`"}
    end
  end

  defp _using_kwargs?(nil), do: []
  defp _using_kwargs?(params), do: Regex.match?(~r/^([a-z_]+:\s(,|[^,]+?))(,\s[a-z_]+:\s(,|[^,]+))*$/i, params)

  defp _parse_params(nil), do: []
  defp _parse_params(params) do
    if _using_kwargs?(params), do: [_parse_kwarg_params(params)], else: _parse_list_params(params)
  end

  defp _parse_list_params(params) do
    params
    |> String.trim
    |> String.split(",")
    |> Enum.map(&(String.trim(&1)))
    |> Enum.map(&_cast_param(&1))
  end

  defp _parse_kwarg_params(param) do
    param
    |> _split_kwarg_pairs()
    |> Enum.reduce(%{}, fn([key,val], acc) -> Map.put(acc, _format_keyword(key), _cast_param(val)) end)
  end

  def _split_kwarg_pairs(params, pairs \\ [])
  def _split_kwarg_pairs("", pairs) do
    pairs |> Enum.reverse
  end
  def _split_kwarg_pairs(params, pairs) do
    with [_, slag, key, value] <- Regex.run(~r/^(([a-z_]+):\s(,|[^,]+?))(?:,\s[a-z_]+:\s(?:,|[^,]+))*$/, params) do
      value = if(nil == Regex.run(~r/[^\s]/, value), do: " ", else: String.trim(value))
      String.replace_leading(params, slag, "")
      |> String.replace(~r/^\s*,\s*/, "")
      |> _split_kwarg_pairs([ [key, value] | pairs ])
    else
      nil -> nil
    end
  end

  defp _format_keyword(key) do
    key |> String.downcase() |> String.to_atom()
  end

  defp _cast_param(param) do
    cond do
      # TODO: May want to do this another way, or validate input on script creation. Maybe a second pass scan that looks for
      # bad objects that current user does not have access to add
      Regex.match?(~r/^TTID:\d+$/, param) -> {:ttid, String.slice(param,5..-1) |> String.to_integer}
        # this lead to an infinite loop
        # ttid = String.slice(param,5..-1)
        # Map.put(DungeonCrawl.TileTemplates.get_tile_template!(ttid), :tile_template_id, ttid)
      Regex.match?(~r/^true$/i, param) -> true
      Regex.match?(~r/^false$/i, param) -> false
      Regex.match?(~r/^\d+\.\d+$/, param) -> String.to_float(param)
      Regex.match?(~r/^\d+$/, param) -> String.to_integer(param)
      Regex.match?(~r/^(not |! ?)?@.+?((!=|==|<=|>=|<|>).+)?$/i, param) -> _normalize_conditional(param)
      true -> param # just a string
    end
  end

  # conditional state value
  defp _normalize_conditional(param) do
    case Regex.named_captures(~r/^(?<neg>not |! ?|)@(?<state_element>.+?)((?<op>!=|==|<=|>=|<|>)(?<value>.+))?$/i, String.trim(param)) do
      %{"neg" => "", "state_element" => state_element, "op" => "", "value" => ""} ->
        ["", :check_state, String.trim(state_element) |> String.to_atom(), "==", true]

      %{"neg" => "", "state_element" => state_element, "op" => op, "value" => value} ->
        ["", :check_state, String.trim(state_element) |> String.to_atom(), op, _cast_param(value)]

      %{"neg" => _, "state_element" => state_element, "op" => "", "value" => ""} ->
        ["!", :check_state, String.trim(state_element) |> String.to_atom(), "==", true]

      %{"neg" => _, "state_element" => state_element, "op" => op, "value" => value} ->
        ["!", :check_state, String.trim(state_element) |> String.to_atom(), op, _cast_param(value)]
    end
  end
end

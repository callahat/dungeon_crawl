defmodule DungeonCrawl.Scripting.Parser do
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
  #become

  #if <condition>, <label>

  #end - stops the program until it receives a message that it can process.

  ## Examples

      iex> Parser.parse(~s/:open\n#become TTID:5/)
      {:ok, %Program{}}

      iex> Parser.parse(~s/#fakecommand/)
      {:error, "Unknown command: `fakecommand`", %Program{}}
  """
  def parse(nil), do: {:ok, %Program{}}
  def parse(""),  do: {:ok, %Program{}}
  def parse(script_string) do
    case _parse_script(String.split(String.trim(script_string), "\n"), %Program{}) do
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
    case Regex.named_captures(~r/^(?<type>#|:|@)(?<instruction>.*)$/, line) do
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
  
  defp _parse_command(line, program) do
    with %{"command" => command} <- match = Regex.named_captures(~r/\A(?<command>[A-Z\d_]+)(?: (?<params>.+))?\z/i, String.trim(line)),
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
        {:error, "Invalid label: `#{line}`", program}
    end
  end

  defp _parse_state_change(element, program) do
    with state_element <- String.trim(String.downcase(element)),
         %{"element" => element, "setting" => setting} <- Regex.named_captures(~r/\A(?<element>[a-z_]+)(?<setting>.+)\z/i, state_element),
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
    with line_number = Enum.count(program.instructions),
         [:text, preceeding_text] <- program.instructions[line_number] do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:text, preceeding_text ++ [text] ]) } }
    else
      _ ->
        line_number = Enum.count(program.instructions) + 1
        {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:text, [text] ]) } }
    end
  end

  defp _sendable_command(command) do
    case String.downcase(command) do
      "become"       -> {:ok, :become}
      "end"          -> {:ok, :end_script}
      "if"           -> {:ok, :jump_if}

      bad_command -> {:error, "Unknown command: `#{bad_command}`"}
    end
  end

  defp _using_kwargs?(nil), do: []
  defp _using_kwargs?(params), do: Regex.match?(~r/^([a-z_]+:\s.+?)(,\s?[a-z_]+:\s.+?)*$/i, params)

  defp _parse_params(nil), do: []
  defp _parse_params(params) do
    if _using_kwargs?(params), do: _parse_kwarg_params(params), else: _parse_list_params(params)
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
    |> String.split(",")
    |> Enum.map(fn(kw) ->
         String.split(kw, ": ")
         |> Enum.map(&(String.trim(&1)))
       end)
    |> Enum.reduce(%{}, fn([key,val], acc) -> Map.put(acc, _format_keyword(key), _cast_param(val)) end)
  end

  defp _format_keyword(key) do
    key |> String.downcase() |> String.to_atom()
  end

  defp _cast_param(param) do
    cond do
      # TODO: May want to do this another way, or validate input on script creation. Maybe a second pass scan that looks for
      # bad objects that current user does not have access to add
      Regex.match?(~r/^TTID:\d+$/, param) -> DungeonCrawl.TileTemplates.get_tile_template!(String.slice(param,5..-1))
      Regex.match?(~r/^true$/i, param) -> true
      Regex.match?(~r/^false$/i, param) -> false
      Regex.match?(~r/^\d+\.\d+$/, param) -> String.to_float(param)
      Regex.match?(~r/^\d+$/, param) -> String.to_integer(param)
      Regex.match?(~r/^(not |! ?)?@.+?(!=|==|<=|>=|<|>).+$/i, param) -> _normalize_conditional(param)
      true -> param # just a string
    end
  end

  # conditional state value
  defp _normalize_conditional(param) do
    case Regex.named_captures(~r/^(?<neg>not |! ?|)@(?<state_element>.+?)((?<op>!=|==|<=|>=|<|>)(?<value>.+))?$/i, String.trim(param)) do
      %{"neg" => "", "state_element" => state_element, "op" => "", "value" => ""} ->
        ["", :check_state, String.trim(state_element)]

      %{"neg" => "", "state_element" => state_element, "op" => op, "value" => value} ->
        ["", :check_state, String.trim(state_element), op, _cast_param(value)]

      %{"neg" => _, "state_element" => state_element, "op" => "", "value" => ""} ->
        ["!", :check_state, String.trim(state_element)]

      %{"neg" => _, "state_element" => state_element, "op" => op, "value" => value} ->
        ["!", :check_state, String.trim(state_element), op, _cast_param(value)]
    end
  end
end
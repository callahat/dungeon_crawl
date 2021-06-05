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

  ### Label

  : - label, used for program flow; it is where the program counter will
             jump when a message is sent, the following are events sent by
             the system

  :open
  :close

  ### Command

  # - command, ie
  #become <kwargs>

  #if <condition>, <label>

  #end - stops the program until it receives a message that it can process.

  ### State Value

  @ - references a state value for the object. This can be used for setting a state value.

  @flag = true

  @counter += 1

  ### Dungeon Value

  @@ - references a state value for the dungeon instance (ie, the current "map"). Can be used for setting a dungeon value

  @@doors_locked = false

  @@countdown -= 1

  ### Map Set Instance Value

  & - references a state value for the map set instance (ie, it can be accessed by the current map as well as other maps
      in the game instance. Can be used for reading or setting a map set value.

  &flag_1 = true

  &switches_on += 1

  ### Other's State Value

  ?<target>@ - refernces the state value of another object. Can be used for setting the state value
               on another object. Target can be a direction or an object id (but cannot target a player tile).
               Does not trigger side effects (such as when a player dies when health reaches 0)

  ?north@blocking = true

  ?12345@ammo += 5

  ### Movement Shorthand

  There can be many movement shorthand commands on the same line. Valid directions are n,s,e, or w
  (north, south, east or west, respectively). The shorthand command is a directive followed by a direction.

  / - shorthand for the GO command; will keep retrying until the move is successful before moving on to the next instruction.
  ? - shorthand for the TRY command; will try to move, but will not retry before continuing with the next instruction.

  /n/n/w?w
  ?s?w?e?n
  /n
  ?w

  ### Text

  <no prefix> - this is treated as text that can be displayed to a player.
  !<label>;   - this is treaded as a text action, which can be displayed to a player and
                has an associated label/message that will be sent to the object when clicked.


  ## Examples

    iex> Parser.parse(~s/#become character: 4/)
    {:ok, %Program{broadcasts: [], instructions: %{1 => [:become, [%{character: "4"}]]}, labels: %{}, locked: false, pc: 1, responses: [], status: :alive}}

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
    other_state_change = "\\?({@.+?}|{\\?.+?}|[^{}@]+?)@"
    case Regex.named_captures(~r/^(?<type>#|:|@@|@|&|#{other_state_change}|\/|\?)(?<instruction>.*)$/, line) do
      %{"type" => "/", "instruction" => _command} ->
        _parse_shorthand_movement(line, program)

      %{"type" => "?", "instruction" => _command} ->
        _parse_shorthand_movement(line, program)

      %{"type" => "#", "instruction" => command} ->
        _parse_command(command, program)

      %{"type" => ":", "instruction" => label} ->
        _parse_label(label, program)

      %{"type" => "@", "instruction" => state_element} ->
        _parse_state_change(:change_state, state_element, program)

      %{"type" => "@@", "instruction" => state_element} ->
        _parse_state_change(:change_instance_state, state_element, program)

      %{"type" => "&", "instruction" => state_element} ->
        _parse_state_change(:change_map_set_instance_state, state_element, program)

      %{"type" => type, "instruction" => state_element} when type != "" ->
        _parse_state_change(:change_other_state, type, state_element, program)

      _ ->
        _handle_text(line, program)
    end
  end

  defp _parse_shorthand_movement(line, program) do
    with steps <- line |> String.trim() |> String.to_charlist() |> Enum.chunk_every(2),
         {:ok, expanded_steps} <- _parse_shorthand_movements(steps),
         line_number <- Enum.count(program.instructions) + 1 do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:compound_move, expanded_steps]) } }
    else
      {:error, msg} -> {:error, msg, program}
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
      ?c -> {:ok, "continue"}
      ?C -> {:ok, "continue"}
      ?p -> {:ok, "player"}
      ?P -> {:ok, "player"}
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
    downcased_line = String.downcase(String.trim(line))
    with %{"label" => label} <- Regex.named_captures(~r/\A(?<label>[a-z\d_]+)\z/i, downcased_line),
         line_number <- Enum.count(program.instructions) + 1,
         existing_labels <- program.labels[label] || [],
         updated_labels <- existing_labels ++ [[line_number, true]] do
      # No need to add the label; its a noop anyway
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:noop, line]),
                        labels: Map.put(program.labels, label, updated_labels)}}
    else
      _ ->
        {:error, "Invalid label: `#{downcased_line}`", program}
    end
  end

  defp _parse_state_change(:change_other_state, other, element, program) do
    with %{"target" => target} <- Regex.named_captures(~r/^\?{?(?<target>.*?)}?@$/, other),
         target <- _cast_other_target(target),
         state_element <- String.trim(String.downcase(element)),
         %{"element" => element, "setting" => setting} <- Regex.named_captures(~r/\A(?<element>[a-z_\d]+)(?<setting>.+)\z/i, state_element),
         element = String.to_atom(element),
         {:ok, op, value} <- _parse_state_setting(setting),
         line_number <- Enum.count(program.instructions) + 1 do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:change_other_state, [target, element, op, value]]) } }
    else
      nil               -> {:error, "Invalid :change_other_state setting: `#{other}` by `#{element}`", program}
      {:error, message} -> {:error, message, program}
    end
  end

  defp _parse_state_change(type, element, program) do
    with state_element <- String.trim(String.downcase(element)),
         %{"element" => element, "setting" => setting} <- Regex.named_captures(~r/\A(?<element>[a-z_\d]+)(?<setting>.+)\z/i, state_element),
         element = String.to_atom(element),
         {:ok, op, value} <- _parse_state_setting(setting),
         line_number <- Enum.count(program.instructions) + 1 do
      {:ok, %{program | instructions: Map.put(program.instructions, line_number, [type, [element, op, value]]) } }
    else
      nil               -> {:error, "Invalid #{type} setting: `#{element}`", program}
      {:error, message} -> {:error, message, program}
    end
  end

  defp _cast_other_target(param) do
    cond do
      Regex.match?(~r/^sender$|^$/, param) -> [:event_sender]
      Regex.match?(~r/^\d+$/, param) -> String.to_integer(param)
      Regex.match?(~r/^@.+?$/, param) -> _normalize_state_arg(param)
      Regex.match?(~r/^\?.+?$/i, param) -> _normalize_special_var(param)
      true -> param # just a string, probably a direction
    end
  end

  defp _parse_state_setting(setting) do
    with %{"op" => op, "value" => value} <- Regex.named_captures(~r/\A\s*(?<op>\+\+|--|(?:\+|-|\*|\/)?=)\s*(?<value>.*)/, String.trim(setting)) do
      {:ok, op, _cast_param(value)}
    else
      _ -> {:error, "Invalid state assignment: `#{setting}`"}
    end
  end

  defp _handle_text(line, program) do
    line_number = Enum.count(program.instructions) + 1

    %{"label" => label, "text" => text} = Regex.named_captures(~r/(?:!(?<label>[A-Za-z\d_]+);)?(?<text>.*)$/, line)

    text_chunks = _interpolations(text)
    params = if label != "", do: [text_chunks, label], else: [text_chunks]

    {:ok, %{program | instructions: Map.put(program.instructions, line_number, [:text, params ]) } }
  end

  defp _interpolations(text) do
    texts = Regex.split ~r/\${.+?}/, text
    interpolations = Regex.scan(~r/\${.+?}/, text)
                     |> Enum.map(&(Enum.at(&1,0)))
    _extract_interpolations(texts, interpolations)
  end
  defp _extract_interpolations(texts, []), do: texts
  defp _extract_interpolations([ text | texts], [interpolation | interpolations]) do
    %{"value" => inner_value} = Regex.named_captures(~r/\${\s*(?<value>.*?)\s*}/, interpolation)
    [ text, _cast_simple_param(inner_value) | _extract_interpolations(texts, interpolations) ]
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
    |> Enum.reduce(%{}, fn([key,val], acc) -> keyword = _format_keyword(key); Map.put(acc, keyword, _cast_kparam(val, keyword)) end)
  end

  def _split_kwarg_pairs(params, pairs \\ [])
  def _split_kwarg_pairs("", pairs) do
    pairs |> Enum.reverse
  end
  def _split_kwarg_pairs(params, pairs) do
    with [_, slag, key, value] <- Regex.run(~r/^(([A-Za-z_]+):\s(,|[^,]+?))(?:,\s[A-Za-z_]+:\s(?:,|[^,]+))*$/, params) do
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

  # Special keywords have an expected format; ie character will be used in become
  defp _cast_kparam(param, :character) do
    cond do
      Regex.match?(~r/^(\?[^@]*?@|@@|@).+?$/i, param) -> _normalize_state_arg(param)
      true -> param
    end
  end
  defp _cast_kparam(param, _keyword), do: _cast_param(param)

  defp _cast_param(param) do
    cond do
      Regex.match?(~r/^true$/i, param) -> true
      Regex.match?(~r/^false$/i, param) -> false
      Regex.match?(~r/^\d+\.\d+$/, param) -> String.to_float(param)
      Regex.match?(~r/^\d+$/, param) -> String.to_integer(param)
      Regex.match?(~r/^(not |! ?)?(\?[^@]*?@|@@|@|&).+?((!=|==|<=|>=|<|>).+)?$/i, param) -> _normalize_conditional(param)
      Regex.match?(~r/^\?.+?$/i, param) -> _normalize_special_var(param)
      true -> param # just a string
    end
  end

  defp _cast_simple_param(param) do
    cond do
      Regex.match?(~r/^true$/i, param) -> true
      Regex.match?(~r/^false$/i, param) -> false
      Regex.match?(~r/^\d+\.\d+$/, param) -> String.to_float(param)
      Regex.match?(~r/^\d+$/, param) -> String.to_integer(param)
      Regex.match?(~r/^(\?[^@]*?@|@@|@|&).+?$/i, param) -> _normalize_state_arg(param)
      Regex.match?(~r/^\?.+?$/i, param) -> _normalize_special_var(param)
      true -> param # just a string
    end
  end

  # conditional state value
  defp _normalize_conditional(param) do
    # todo: look into relaxing the left/right charcters for the capture groups
    case Regex.named_captures(~r/^(?<neg>not |! ?|)?(?<left>[?&@_A-Za-z0-9\+{}]+?)\s*((?<op>!=|==|<=|>=|<|>)\s*(?<right>[?&@_A-Za-z0-9\+ ]+?))?$/i,
                              String.trim(param)) do
      %{"neg" => "", "left" => left, "op" => "", "right" => ""} ->
        _normalize_state_arg(left)

      %{"neg" => "", "left" => left, "op" => op, "right" => right} ->
        [_normalize_state_arg(left), op, _cast_simple_param(right)]

      %{"neg" => _, "left" => left, "op" => "", "right" => ""} ->
        ["!", _normalize_state_arg(left)]

      %{"neg" => _, "left" => left, "op" => op, "right" => right} ->
        ["!", _normalize_state_arg(left), op, _cast_simple_param(right)]

      _ -> :error
    end
  end

  defp _normalize_state_arg(arg) do
    case Regex.named_captures(~r/^(?<type>\?.*?@|@@|@|&)(?<state_element>[_A-Za-z0-9]+?)\s*?(\+\s?(?<concat>[_A-Za-z0-9]+?))?\s*$/i, String.trim(arg)) do
      %{"type" => "?random@", "state_element" => number} ->
        if Regex.match?(~r/^\d{1,3}$/, number) do
          {:random, 1..String.to_integer(number)}
        else
          :error
        end

      %{"type" => type, "state_element" => state_element, "concat" => ""} ->
        {_state_var_type(type), String.trim(state_element) |> String.to_atom()}

      %{"type" => type, "state_element" => state_element, "concat" => concat} ->
        {_state_var_type(type), String.trim(state_element) |> String.to_atom(), String.replace(concat, ~r/^\s*\+\s*/,"")}

      _ -> # if this happens, then this method is being called in the wrong place
        :error
    end
  end

  defp _state_var_type(type) do
    case Regex.named_captures(~r/^(?<lead>\?|@@|@|&)(?<mid>.*?)(?<tail>@|)$/, type) do
      %{"lead" => "@", "mid" => "", "tail" => ""} ->
        :state_variable

      %{"lead" => "@@", "mid" => "", "tail" => ""} ->
        :instance_state_variable

      %{"lead" => "&", "mid" => "", "tail" => ""} ->
        :map_set_instance_state_variable

      %{"lead" => "?", "mid" => who, "tail" => "@"} ->
        case Regex.named_captures(~r/^(?:(?<sender>[^@{}]*$|$)|{@(?<variable>[^@]+)})$/, who) do
          %{"variable" => variable} when variable != "" -> {:state_variable, String.to_atom(variable)}

          %{"sender" => "sender"}  -> :event_sender_variable
          %{"sender" => ""}        -> :event_sender_variable

          %{"sender" => "any_player"} -> :any_player

          %{"sender" => direction} -> {:direction, direction}

          _ -> :error
        end

      #_ -> :error # should not even get here given the regex should have failed out in an upstream function
    end
  end

  def _normalize_special_var(param) do
    case Regex.named_captures(~r/^\?(?<variable>.*)/i, String.trim(param)) do
      %{"variable" => "sender"} ->
        [:event_sender]

      _ ->
       :error
    end
  end
end

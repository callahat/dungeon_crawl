defmodule DungeonCrawl.Scripting.ProgramValidator do
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  import DungeonCrawl.Scripting.VariableResolutionStub, only: [resolve_variable_map: 2]

  @valid_shifts ["clockwise", "counterclockwise"]
  @valid_facings ["north", "south", "west", "east", "up", "down", "left", "right", "reverse", "clockwise", "counterclockwise", "player"]
  @valid_directions ["north", "south", "west", "east", "up", "down", "left", "right", "idle", "continue", "player"]

  @doc """
  Validates the commands and their inputs of a program. User is used to validate a given tile template id
  can be used for that user. A normal user will only be able to use a slug for a template that they own and
  is active.

  ## Examples

    iex> ProgramValidator.validate(%Program{}, user)
    {:ok, %Program{}}

    iex> Parser.parse(~s/#fakecommand/)
    {:error, [<List of errors>], %Program{}}
  """
  def validate(%Program{} = program, user) do
    case _validate(program, Enum.to_list(program.instructions), [], user) do
      {:ok, program} -> {:ok, program}

      {:error, messages, program} ->
        # For large programs, it seems that the list order is not consistent, so an Enum.reverse isn't sufficient
        # to get the order right, so Enum.reverse(messages) gets a scrambled order anyway when the program gets longer.
        messages_sorted = Enum.sort(messages, fn(a,b) ->
          String.to_integer(Regex.named_captures(~r/(?<num>\d+):/, a)["num"]) < String.to_integer(Regex.named_captures(~r/(?<num>\d+):/, b)["num"]) end)
        {:error, messages_sorted, program}
    end
  end
  # TODO: more general validator to validaet param list lengths

  defp _validate(program, [], [], _user), do: {:ok, program}
  defp _validate(program, [], errors, _user), do: {:error, errors, program}

  # only definind specific _validate b/c not all commands will have input that could be invalid if it gets past the parser
  defp _validate(program, [ {line_no, [ :become, params ]} | instructions], errors, user) do
    _validate_tile_kwargs(line_no, "BECOME", params, program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [ :change_state, params ]} | instructions], errors, user) do
    _validate_change(line_no, params, program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [ :change_level_instance_state, params ]} | instructions], errors, user) do
    _validate_change(line_no, params, program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [ :change_dungeon_instance_state, params ]} | instructions], errors, user) do
    _validate_change(line_no, params, program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [ :change_other_state, params ]} | instructions], errors, user) do
    _validate_change(line_no, params, program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [ :cycle, [ wait_cycles ] ]} | instructions], errors, user) when is_integer(wait_cycles) do
    if wait_cycles > 0 do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: CYCLE command has invalid param `#{wait_cycles}`" | errors], user)
    end
  end
  defp _validate(program, [ {line_no, [ :cycle, [ wait_cycles ] ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: CYCLE command has invalid param `#{wait_cycles}`" | errors], user)
  end

  defp _validate(program, [ {line_no, [:equip, [what, who] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:equip, [what, who, nil, nil] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:equip, [what, who, max] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:equip, [what, who, max, nil] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:equip, [_what, who, max, label] ]} | instructions], errors, user) do
    errors = unless Enum.member?([[:event_sender], [:self]], who) or Enum.member?(@valid_directions -- ["idle"], who) or is_tuple(who),
                    do: ["Line #{line_no}: EQUIP command references invalid direction `#{as_binary who}`" | errors],
                    else: errors
    errors = unless is_nil(max) or (is_number(max) and max > 0 || is_tuple(max)),
                    do: ["Line #{line_no}: EQUIP command has invalid maximum amount `#{max}`" | errors],
                    else: errors
    errors = unless is_nil(label) or Program.line_for(program, label),
                    do: ["Line #{line_no}: EQUIP command references nonexistant label `#{label}`" | errors],
                    else: errors

    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:facing, [ direction ] ]} | instructions], errors, user) do
    if @valid_facings |> Enum.member?(direction) or is_tuple(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: FACING command references invalid direction `#{as_binary direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [:gameover, [""] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:gameover, [true, "Win", [:event_sender]] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:gameover, [victory] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:gameover, [victory, "Win", [:event_sender]] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:gameover, [victory, result] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:gameover, [victory, result, [:event_sender]] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:gameover, [victory, _result, who] ]} | instructions], errors, user) do
    errors = unless is_boolean(victory) or is_tuple(victory),
               do: ["Line #{line_no}: GAMEOVER command has invalid 1st parameter `#{victory}`" | errors],
               else: errors
    errors = unless Enum.member?([[:event_sender], [:self]], who) or is_tuple(who) or who == "all",
               do: ["Line #{line_no}: GAMEOVER command has invalid 3rd parameter `#{as_binary who}`" | errors],
               else: errors
    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:give, [what, amount, who] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:give, [what, amount, who, nil, nil] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:give, [what, amount, who, max] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:give, [what, amount, who, max, nil] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:give, [_what, amount, who, max, label] ]} | instructions], errors, user) do
    errors = unless is_number(amount) and amount > 0 || is_tuple(amount),
               do: ["Line #{line_no}: GIVE command has invalid amount `#{as_binary amount}`" | errors],
               else: errors
    errors = unless Enum.member?([[:event_sender], [:self]], who) or Enum.member?(@valid_directions -- ["idle"], who) or is_tuple(who),
               do: ["Line #{line_no}: GIVE command references invalid direction `#{as_binary who}`" | errors],
               else: errors
    errors = unless is_nil(max) or (is_number(max) and max > 0 || is_tuple(max)),
               do: ["Line #{line_no}: GIVE command has invalid maximum amount `#{max}`" | errors],
               else: errors
    errors = unless is_nil(label) or Program.line_for(program, label),
               do: ["Line #{line_no}: GIVE command references nonexistant label `#{label}`" | errors],
               else: errors

    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:go, [direction] ]} | instructions], errors, user) do
    if @valid_directions |> Enum.member?(direction) or is_tuple(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: GO command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [ :jump_if, [params] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [ :jump_if, [params, 1] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [ :jump_if, [params, label] ]} | instructions], errors, user)
         when params != :error
         when length(params) == 2
         when length(params) == 3
         when length(params) == 4 do
    cond do
      (is_list(params) && Enum.any?(params, fn param -> param == :error end)) ->
        _validate(program, instructions, ["Line #{line_no}: IF command malformed" | errors], user)
      is_integer(label) ->
        if label < 1 do
          _validate(program, instructions, ["Line #{line_no}: IF command jump distance must be positive `#{as_binary label}`" | errors], user)
        else
          _validate(program, instructions, errors, user)
        end
      Program.line_for(program, label) ->
        _validate(program, instructions, errors, user)
      true ->
        _validate(program, instructions, ["Line #{line_no}: IF command references nonexistant label `#{label}`" | errors], user)
    end
  end
  defp _validate(program, [ {line_no, [ :jump_if, _ ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: IF command malformed" | errors], user)
  end

  defp _validate(program, [ {line_no, [:move, [direction] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:move, [direction, false] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:move, [direction, _] ]} | instructions], errors, user) do
    if @valid_directions |> Enum.member?(direction) or is_tuple(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: MOVE command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {_line_no, [ :passage, [match_key] ]} | instructions], errors, user) when match_key != "" do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [ :passage, bad_params ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: PASSAGE command has invalid params `#{as_binary bad_params}`" | errors], user)
  end

  defp _validate(program, [ {_line_no, [:push, [{_state_variable, _var}, {_state_variable2, _var2}] ]} | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {_line_no, [:push, [{_state_variable, _var}] ]} | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [:push, [direction] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:push, [direction, 1] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:push, [{_state_variable, _var}, range] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:push, ["south", range] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:push, [direction, range] ]} | instructions], errors, user) do
    errors = unless @valid_directions |> Enum.member?(direction),
               do: ["Line #{line_no}: PUSH command references invalid direction `#{direction}`" | errors],
               else: errors
    errors = unless is_number(range) && range >= 0,
               do: ["Line #{line_no}: PUSH command has invalid range `#{range}`" | errors],
               else: errors

    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [ :put, params ]} | instructions], errors, user) do
    _validate_tile_kwargs(line_no, "PUT", params, program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:random, [state_var | list]]} | instructions], errors, user)
      when list != [] and is_list(list) do
    case state_var do
      {:state_variable, _} -> _validate(program, instructions, errors, user)
      {:instance_state_variable, _} -> _validate(program, instructions, errors, user)
      {:dungeon_instance_state_variable, _} -> _validate(program, instructions, errors, user)
      var when is_binary(var) -> _validate(program, instructions, errors, user)
      var -> _validate(program, instructions, ["Line #{line_no}: RANDOM command has an invalid variable specified #{as_binary var}" | errors], user)
    end
  end
  defp _validate(program, [ {line_no, [:random, _]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: RANDOM command has an invalid number of parameters" | errors], user)
  end

  defp _validate(program, [ {line_no, [ :replace, params ]} | instructions], errors, user) do
    _validate_tile_kwargs(line_no, "REPLACE", params, program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:remove, params ]} | instructions], errors, user) do
    _validate_tile_kwargs(line_no, "REMOVE", params, program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:restore, [label] ]} | instructions], errors, user) do
    if program.labels[String.downcase(label)] do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: RESTORE command references nonexistant label `#{label}`" | errors], user)
    end
  end

  defp _validate(program, [ {_line_no, [:send_message, [_label] ]} | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {_line_no, [:send_message, [_label, _target] ]} | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {_line_no, [:send_message, [_label, _target, _delay] ]} | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [:send_message, _ ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: SEND command has an invalid number of parameters" | errors], user)
  end

  defp _validate(program, [ {_line_no, [:sequence, [_state_var | list]]} | instructions], errors, user)
      when list != [] and is_list(list) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [:sequence, _] } | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: SEQUENCE command has an invalid number of parameters" | errors], user)
  end

  defp _validate(program, [ {line_no, [:shift, [rotation] ]} | instructions], errors, user) do
    if @valid_shifts |> Enum.member?(rotation) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: SHIFT command references invalid rotation `#{rotation}`" | errors], user)
    end
  end

  defp _validate(program, [ {_line_no, [:shoot, [{_state_variable, _var}] ]} | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [:shoot, [direction] ]} | instructions], errors, user) do
    if (@valid_directions -- ["idle"]) |> Enum.member?(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: SHOOT command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [:sound, [slug] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:sound, [slug, "nearby"] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:sound, [slug, target] ]} | instructions], errors, user) do
    errors = unless is_binary(slug),
                    do: ["Line #{line_no}: SOUND command references invalid slug `#{as_binary slug}`" | errors],
                    else: errors
    errors = unless Enum.member?(["all", "nearby", [:event_sender], [:self]], target) or is_tuple(target),
                    do: ["Line #{line_no}: SOUND command references invalid target `#{as_binary target}`" | errors],
                    else: errors
    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [:sound, params ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: SOUND command has invalid params `#{as_binary params}`" | errors], user)
  end

  defp _validate(program, [ {line_no, [:take, [_what, amount, who] ]} | instructions], errors, user) do
    errors = unless is_number(amount) and amount > 0 || is_tuple(amount),
               do: ["Line #{line_no}: TAKE command has invalid amount `#{amount}`" | errors],
               else: errors
    errors = unless Enum.member?([[:event_sender], [:self]], who) or Enum.member?(@valid_directions -- ["idle"], who) or is_tuple(who),
               do: ["Line #{line_no}: TAKE command references invalid direction `#{as_binary who}`" | errors],
               else: errors
    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:take, [_what, amount, who, label] ]} | instructions], errors, user) do
    errors = unless is_number(amount) and amount > 0 || is_tuple(amount),
               do: ["Line #{line_no}: TAKE command has invalid amount `#{amount}`" | errors],
               else: errors
    errors = unless Enum.member?([[:event_sender], [:self]], who) or Enum.member?(@valid_directions -- ["idle"], who) or is_tuple(who),
               do: ["Line #{line_no}: TAKE command references invalid direction `#{as_binary who}`" | errors],
               else: errors
    errors = unless Program.line_for(program, label),
               do: ["Line #{line_no}: TAKE command references nonexistant label `#{label}`" | errors],
               else: errors
    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:target_player, [what] ]} | instructions], errors, user) do
    errors = unless String.downcase(what) == "nearest" || String.downcase(what) == "random" ,
               do: ["Line #{line_no}: TARGET_PLAYER command specifies invalid target `#{what}`" | errors],
               else: errors
    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:text, [[{:condition, :error}, _lines]] ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: TEXT conditional is invalid" | errors], user)
  end

  defp _validate(program, [ {line_no, [:text, [_text, label] ]} | instructions], errors, user) do
    cond do
      Program.line_for(program, label) ->
        _validate(program, instructions, errors, user)
      true ->
        _validate(program, instructions, ["Line #{line_no}: TEXT command references nonexistant label `#{label}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [:transport, [who, level] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:transport, [who, level, nil] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:transport, [_who, level, _match_key] ]} | instructions], errors, user) do
    errors = if !is_integer(level) && level != "up" && level != "down" && !is_tuple(level),
               do:   ["Line #{line_no}: TRANSPORT command level kwarg is invalid: `#{as_binary level}`" | errors],
               else: errors

    _validate(program, instructions, errors, user)
  end
  defp _validate(program, [ {line_no, [:transport, params ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: TRANSPORT command has invalid number of params: `#{as_binary params}`" | errors], user)
  end

  defp _validate(program, [ {line_no, [:try, [direction] ]} | instructions], errors, user) do
    if @valid_directions |> Enum.member?(direction) or is_tuple(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: TRY command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [:unequip, [what, who] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:unequip, [what, who, nil] ]} | instructions], errors, user)
  end
  defp _validate(program, [ {line_no, [:unequip, [_what, who, label] ]} | instructions], errors, user) do
    errors = unless Enum.member?([[:event_sender], [:self]], who) or Enum.member?(@valid_directions -- ["idle"], who) or is_tuple(who),
                    do: ["Line #{line_no}: UNEQUIP command references invalid direction `#{as_binary who}`" | errors],
                    else: errors
    errors = unless is_nil(label) or Program.line_for(program, label),
                    do: ["Line #{line_no}: UNEQUIP command references nonexistant label `#{label}`" | errors],
                    else: errors

    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:zap, [label] ]} | instructions], errors, user) do
    if program.labels[String.downcase(label)] do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: ZAP command references nonexistant label `#{label}`" | errors], user)
    end
  end

  defp _validate(program, [ _nothing_to_validate | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end

  defp _validate_change(line_no, [what, operator, value], program, instructions, errors, user) do
    _validate_change(line_no, [nil, what, operator, value], program, instructions, errors, user)
  end
  defp _validate_change(line_no, [_who, _what, operator, value], program, instructions, errors, user) do
    errors = if (operator == "--" || operator == "++") && (value != "" || value == nil) do
               ["Line #{line_no}: CHANGE command #{ operator } takes only one operand, got `#{ value }`" | errors]
             else
               errors
             end
    _validate(program, instructions, errors, user)
  end

  defp _validate_tile_kwargs(line_no, command, params, program, instructions, errors, user) do
    if is_map(Enum.at(params, 0)) && length(params) == 1 do
      params = Enum.at(params, 0)
      params = resolve_variable_map(%{}, params)
      dummy_template = %TileTemplate{character: ".", name: "Floor", description: "Just a dusty floor"}
      # settable_params = resolve_variable_map(%{}, Map.take(params, [:character, :color, :background_color]))
      settable_params = Map.take(params, ["character", "color", "background_color"])
      changeset =  TileTemplate.changeset(dummy_template, settable_params)

      errors = _validate_slug(command, line_no, params, errors, user)
      errors = if command == "PUT" &&
                    ((params["row"] && is_nil(params["col"])) || (is_nil(params["row"]) && params["col"])) do
                 ["Line #{line_no}: #{command} command must have both row and col or neither: `row: #{as_binary(params["row"])}, col: #{as_binary(params["col"])}`" | errors]
               else
                 errors
               end
      errors = if (command == "REMOVE" || command == "REPLACE") &&
                    !Enum.any?(Map.keys(params), fn k -> k =~ ~r/^target/ end ) do
                 ["Line #{line_no}: #{command} command has no target KWARGs: `#{as_binary params}`" | errors]
               else
                 errors
               end

      if changeset.errors == [] do
        _validate(program, instructions, errors, user)
      else
        errs = Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
                   Enum.reduce(opts, msg, fn {key, value}, acc ->
                     String.replace(acc, "%{#{key}}", to_string(value))
                   end)
                 end)
        error_messages = errs
          |> Map.keys
          |> Enum.map(fn(k) -> "#{k} - #{errs[k]}" end)
          |> Enum.join("; ")

        _validate(program, instructions, ["Line #{line_no}: #{command} command has errors: `#{error_messages}`" | errors], user)
      end
    else
      _validate(program, instructions, ["Line #{line_no}: #{command} command params not being detected as kwargs `#{as_binary params}`" | errors], user)
    end
  end

  defp _validate_slug(command, line_no, params, errors, user) do
    tt = TileTemplates.get_tile_template(params["slug"], :validation)
    cond do
      is_nil(params["slug"]) || is_nil(user) || params["slug"] == "stubbed_slug" ->
        errors

      is_nil(tt) ->
        ["Line #{line_no}: #{command} command references a SLUG that does not match a template `#{params["slug"]}`" | errors]

      tt.public || user.is_admin || (user.id == tt.user_id) ->
        errors

      true ->
        ["Line #{line_no}: #{command} command references a SLUG that you can't use `#{params["slug"]}`" | errors]
    end
  end

  defp as_binary(nil), do: "<nil>"
  defp as_binary(""), do: "<empty string>"
  defp as_binary(what) when is_binary(what), do: what
  defp as_binary(what), do: inspect(what)
end

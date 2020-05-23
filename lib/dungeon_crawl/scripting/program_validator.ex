defmodule DungeonCrawl.Scripting.ProgramValidator do
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  @valid_facings ["north", "south", "west", "east", "up", "down", "left", "right", "reverse", "clockwise", "counterclockwise", "player"]
  @valid_directions ["north", "south", "west", "east", "up", "down", "left", "right", "idle", "continue", "player"]

  @doc """
  Validates the commands and their inputs of a program. User is used to validate a given tile template id
  can be used for that user. A normal user will only be able to use a TTID for a template that they own and
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

  defp _validate(program, [], [], _user), do: {:ok, program}
  defp _validate(program, [], errors, _user), do: {:error, errors, program}

  # only definind specific _validate b/c not all commands will have input that could be invalid if it gets past the parser
  defp _validate(program, [ {_line_no, [ :become, [{:ttid, _ttid}]]} | instructions], errors, nil) do
    _validate(program, instructions, errors, nil)
  end
  defp _validate(program, [ {line_no, [ :become, [{:ttid, ttid}]]} | instructions], errors, user) do
    tt = TileTemplates.get_tile_template!(ttid)
    if user.is_admin || (user.id == tt.user_id && tt.active && ! tt.deleted_at) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: BECOME command references a TTID that you can't use `#{ttid}`" | errors], user)
    end
  end
  defp _validate(program, [ {line_no, [ :become, [params] ]} | instructions], errors, user) when is_map(params) do
    dummy_template = %TileTemplate{character: ".", name: "Floor", description: "Just a dusty floor"}
    settable_fields = [:character, :color, :background_color, :state, :script, :tile_template_id]
    changeset =  TileTemplate.changeset(dummy_template, Map.take(params, settable_fields))

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

      _validate(program, instructions, ["Line #{line_no}: BECOME command has errors: `#{error_messages}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [ :become, params ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: BECOME command params not being detected as kwargs `#{inspect params}`" | errors], user)
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

  defp _validate(program, [ {line_no, [ :facing, [ direction ] ]} | instructions], errors, user) do
    if @valid_facings |> Enum.member?(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: FACING command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [:give, [what, amount, who] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:give, [what, amount, who, nil, nil] ]} | instructions], errors, user)
  end

  defp _validate(program, [ {line_no, [:give, [what, amount, who, max] ]} | instructions], errors, user) do
    _validate(program, [ {line_no, [:give, [what, amount, who, max, nil] ]} | instructions], errors, user)
  end

  defp _validate(program, [ {line_no, [:give, [_what, amount, who, max, label] ]} | instructions], errors, user) do
    errors = unless is_number(amount) and amount > 0 || is_tuple(amount),
               do: ["Line #{line_no}: GIVE command has invalid amount `#{amount}`" | errors],
               else: errors
    errors = unless who == [:event_sender] or Enum.member?(@valid_directions -- ["idle"], who),
               do: ["Line #{line_no}: GIVE command references invalid direction `#{who}`" | errors],
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
    if @valid_directions |> Enum.member?(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: GO command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ {line_no, [ :jump_if, [params, label] ]} | instructions], errors, user)
         when params != :error
         when length(params) == 2
         when length(params) == 3
         when length(params) == 4 do
    cond do
      (is_list(params) && Enum.any?(params, fn param -> param == :error end)) ->
        _validate(program, instructions, ["Line #{line_no}: IF command malformed" | errors], user)
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
    if @valid_directions |> Enum.member?(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: MOVE command references invalid direction `#{direction}`" | errors], user)
    end
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
  defp _validate(program, [ {line_no, [:send_message, _ ]} | instructions], errors, user) do
    _validate(program, instructions, ["Line #{line_no}: SEND command has an invalid number of parameters" | errors], user)
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

  defp _validate(program, [ {line_no, [:take, [_what, amount, who] ]} | instructions], errors, user) do
    errors = unless is_number(amount) and amount > 0,
               do: ["Line #{line_no}: TAKE command has invalid amount `#{amount}`" | errors],
               else: errors
    errors = unless who == [:event_sender] or Enum.member?(@valid_directions -- ["idle"], who),
               do: ["Line #{line_no}: TAKE command references invalid direction `#{who}`" | errors],
               else: errors
    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:take, [_what, amount, who, label] ]} | instructions], errors, user) do
    errors = unless is_number(amount) and amount > 0 || is_tuple(amount),
               do: ["Line #{line_no}: TAKE command has invalid amount `#{amount}`" | errors],
               else: errors
    errors = unless who == [:event_sender] or Enum.member?(@valid_directions -- ["idle"], who),
               do: ["Line #{line_no}: TAKE command references invalid direction `#{who}`" | errors],
               else: errors
    errors = unless Program.line_for(program, label),
               do: ["Line #{line_no}: TAKE command references nonexistant label `#{label}`" | errors],
               else: errors
    _validate(program, instructions, errors, user)
  end

  defp _validate(program, [ {line_no, [:try, [direction] ]} | instructions], errors, user) do
    if @valid_directions |> Enum.member?(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: TRY command references invalid direction `#{direction}`" | errors], user)
    end
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
end

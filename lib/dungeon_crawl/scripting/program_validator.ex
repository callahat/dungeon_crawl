defmodule DungeonCrawl.Scripting.ProgramValidator do
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

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
        {:error, Enum.reverse(messages), program}
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

  defp _validate(program, [ {line_no, [ :jump_if, [[_neg, _command, _var, _op, _value], label] ]} | instructions], errors, user) do
   if program.labels[label] do
      _validate(program, instructions, errors, user)
    else
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
    if ["north", "south", "west", "east", "up", "down", "left", "right", "idle"] |> Enum.member?(direction) do
      _validate(program, instructions, errors, user)
    else
      _validate(program, instructions, ["Line #{line_no}: MOVE command references invalid direction `#{direction}`" | errors], user)
    end
  end

  defp _validate(program, [ _nothing_to_validate | instructions], errors, user) do
    _validate(program, instructions, errors, user)
  end
end

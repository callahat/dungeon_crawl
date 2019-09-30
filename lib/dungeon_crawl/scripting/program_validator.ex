defmodule DungeonCrawl.Scripting.ProgramValidator do
  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.TileTemplates.TileSeeder
  alias DungeonCrawl.TileTemplates.TileTemplate

  @doc """
  Validates the commands and their inputs of a program.

  ## Examples

    iex> ProgramValidator.validate(%Program{})
    {:ok, %Program{}}

    iex> Parser.parse(~s/#fakecommand/)
    {:error, [<List of errors>], %Program{}}
  """
  def validate(%Program{} = program) do
    case _validate(program, Enum.to_list(program.instructions), []) do
      {:ok, program} -> {:ok, program}

      {:error, messages, program} ->
        {:error, Enum.reverse(messages), program}
    end
  end

  defp _validate(program, [], []), do: {:ok, program}
  defp _validate(program, [], errors), do: {:error, errors, program}

  # only definind specific _validate b/c not all commands will have input that could be invalid if it gets past the parser
  defp _validate(program, [ {line_no, [ :become, params ]} | instructions], errors) do
    dummy_template = TileSeeder.rock_tile()
    settable_fields = [:character, :color, :background_color, :state, :script, :tile_template_id]
    changeset =  TileTemplate.changeset(dummy_template, Map.take(Enum.fetch!(params,0), settable_fields))

    if changeset.errors == [] do
      _validate(program, instructions, errors)
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

      _validate(program, instructions, ["Line #{line_no}: BECOME command has errors: `#{error_messages}`" | errors])
    end
  end

  defp _validate(program, [ {line_no, [ :if, [_condition, label] ]} | instructions], errors) do
    if program.labels[label] do
      _validate(program, instructions, errors)
    else
      _validate(program, instructions, ["Line #{line_no}: IF command references nonexistant label `#{label}`" | errors])
    end
  end

  defp _validate(program, [ _nothing_to_validate | instructions], errors) do
    _validate(program, instructions, errors)
  end
end

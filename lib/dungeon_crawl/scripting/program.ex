defmodule DungeonCrawl.Scripting.Program do
  @doc """
  A struct containing the representation of a program and its state.
  """
  defstruct status: :dead,
            pc: 1,
            lc: 0,
            instructions: %{},
            labels: %{},
            locked: false,
            broadcasts: [],
            responses: [],
            wait_cycles: 5,
            event_sender: nil

  @doc """
  Returns the line number for the given active label for the program.
  If there is no active label, returns `nil`.

  ## Examples

    iex> Program.line_for(%Program{}, "THUD")
    4

    iex> Program.line_for(%Program{}, "Fake")
    nil
  """
  def line_for(program, label) do
    with normalized_label <- String.downcase(label),
         labels when not is_nil(labels) <- program.labels[normalized_label],
         [[line_number, _]] <- labels |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1) do
      line_number
    else
      _ -> nil
    end
  end
end

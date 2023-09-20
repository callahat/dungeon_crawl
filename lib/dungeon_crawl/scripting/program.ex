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
            wait_cycles: 0,
            messages: [],
            timed_messages: []

  @doc """
  Returns the line number for the given active label for the program.
  If there is no active label, returns `nil`.

  ## Examples

    iex> Program.line_for(%Program{}, "THUD")
    4

    iex> Program.line_for(%Program{}, "Fake")
    nil
  """
  def line_for(program, label) when is_binary(label) do
    with normalized_label <- String.downcase(label),
         labels when not is_nil(labels) <- program.labels[normalized_label],
         [[line_number, _]] <- labels |> Enum.filter(fn([_l,a]) -> a end) |> Enum.take(1) do
      line_number
    else
      _ -> nil
    end
  end
  def line_for(_, _), do: nil

  @doc """
  Adds a message to the program. Messages are added at the end of the list.
  """
  def send_message(program, label, sender, 0) do
    # TODO: Probably want to have the programs be their own separate processes eventually.
    messages = Enum.reverse([{label, sender} | Enum.reverse(program.messages) ])
    %{ program | messages: messages }
  end
  def send_message(program, label, sender, delay) do
    trigger_time = DateTime.utc_now |> DateTime.add(delay, :second)
    %{ program | timed_messages: [{trigger_time, label, sender} | program.timed_messages] }
  end
end

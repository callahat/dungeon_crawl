defmodule DungeonCrawl.Scripting.Program do
  @doc """
  A struct containing the representation of a program and its state.
  """
  defstruct status: :dead, pc: 1, instructions: %{}, labels: %{}, locked: false, broadcasts: [], responses: [], wait_cycles: 0
end

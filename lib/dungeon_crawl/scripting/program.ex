defmodule DungeonCrawl.Scripting.Program do
  defstruct status: :dead, pc: 1, instructions: %{}, labels: %{}, locked: false, broadcasts: [], responses: []
end

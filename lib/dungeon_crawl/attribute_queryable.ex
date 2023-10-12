defmodule DungeonCrawl.AttributeQueryable do
  @moduledoc """
  Adds a function that generates a query that matches on all the given fields, including nil.
  """

  defmacro __using__(_params) do
    quote do
      import Ecto.Query, warn: false

      def attrs_query(attrs) do
        Enum.sort(attrs)
        |> Enum.reduce(__MODULE__,
          fn {x,y}, query ->
            _attrs_where(query, {x, y})
          end)
      end

      defp _attrs_where(query, {key,   nil}), do: where(query, [record], is_nil(field(record, ^key)))
      defp _attrs_where(query, {key, value}), do: where(query, ^[{key, value}])
    end
  end

end

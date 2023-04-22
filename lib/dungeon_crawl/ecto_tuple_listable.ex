defmodule DungeonCrawl.EctoTupleListable do
  @moduledoc """
  Adds functions for custom ecto types consisting of a two element
  tuple that will be persisted to a jsonb column.
  The tuple will be converted into an array when going into the jsonb
  column and converted back to a tuple on retrieval.

  When using this module, two validation functions are required.
  These will be used to validate the type of the first and second
  elements in the tuple respectively.
  """

  defmacro __using__([validation_1, validation_2]) do
    quote do
      use Ecto.Type
      def type, do: :jsonb

      # Ideally data will already be list with tuples
      def cast(data) do
        cond do
          is_nil(data) || data == []->
            {:ok, []}

          _valid_inner_tuple(data) ->
            {:ok, data}

          # likely won't get this one in the wild, but just in case handle it gracefully
          _valid_inner_list(data) ->
            {:ok, _tuple_the_list(data)}

          true ->
            :error
        end
      end

      # when loading from the database it will be an array of arrays due to JSONB
      def load(data) do
        if _valid_inner_list(data) do
          {:ok, _tuple_the_list(data)}
        else
          :error
        end
      end

      # the tuple needs to be turned into an array to be able to save it in JSONB
      def dump(data) do
        cond do
          is_nil(data) ->
            {:ok, []}

          _valid_inner_list(data) ->
            {:ok, data}

          _valid_inner_tuple(data) ->
            detupled_data =
              data
              |> Enum.map(fn {a, b} -> [a, b] end)

            { :ok, detupled_data }

          true ->
            :error
        end
      end

      defp _tuple_the_list(data) do
        data
        |> Enum.map(fn [a, b] -> {a, b} end)
      end

      # The data being saved/loaded is internal, so it should not be subject to
      # bad user input. However its good to double check, but any errors the
      # user cannot do anything about.
      # Basically checks for corrupt data.
      defp _valid_inner_tuple(data) do
        is_list(data) &&
          Enum.all?(data, fn
            {a, b} -> unquote(validation_1).(a) && unquote(validation_2).(b)
            _ -> false
          end)
      end

      defp _valid_inner_list(data) do
        is_list(data) &&
          Enum.all?(data, fn
            [a, b] -> unquote(validation_1).(a) && unquote(validation_2).(b)
            _ -> false
          end)
      end
    end
  end
end
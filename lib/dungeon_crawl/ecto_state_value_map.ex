defmodule DungeonCrawl.EctoStateValueMap do
  @moduledoc """
  Ecto type for state values. These consist of key value pairs, which
  were converted into a CSV to be stored in a string in the database.

  Note: this is a step away from manually using `parsed_state` and `state` as two separate
        fields, the former being virtual. This type may go away in favor of something more native,
        such as changing the state field in the DB from string to json.
  """

  use Ecto.Type
  def type, do: :string

  alias DungeonCrawl.StateValue.Parser

  # The state in its `parsed_state` format
  def cast(data) do
    cond do
      is_nil(data) || data == %{} || data == "" ->
        {:ok, %{}}

      is_binary(data) ->
        _parse(data)

      is_map(data) ->
        {:ok, data}

      true ->
        :error
    end
  end

  # change from the DB representation to how the `parsed_state`
  def load(data) do
    if is_binary(data) do
      _parse(data)
    else
      :error
    end
  end

  # ensure its ready to be written to the DB
  def dump(data) do
    cond do
      is_nil(data) || data == %{} ->
        {:ok, ""}

      is_binary(data) ->
        {:ok, data}

      is_map(data) ->
        { :ok, Parser.stringify(data) }

      true ->
        :error
    end
  end

  defp _parse(data) do
    case Parser.parse(data) do
      {:ok, data} -> {:ok, data}
      _error      -> :error
    end
  end
end

defmodule DungeonCrawl.EctoStateValueMap do
  @moduledoc """
  Ecto type for state values. These consist of key value pairs, which
  were converted into a CSV to be stored in a string in the database.

  Note: this is a step away from manually using `parsed_state` and `state` as two separate
        fields, the former being virtual. This type may go away in favor of something more native.
  """

  use Ecto.Type
  def type, do: :string

  alias DungeonCrawl.StateValue.Parser

  # The state in its `parsed_state` format
  def cast(data) do
    cond do
      is_nil(data) || data == %{}->
        {:ok, %{}}

      is_binary(data) ->
        {:ok, Parser.parse!(data)}

      is_map(data) ->
        {:ok, data}

      true ->
        :error
    end
  end

  # change from the DB representation to how the `parsed_state`
  def load(data) do
    if is_binary(data) do
      {:ok, Parser.parse!(data)}
    else
      :error
    end
  end

  # turn the `parsd_state` back into a string
  def dump(data) do
    cond do
      is_nil(data) || data == %{} ->
        {:ok, nil}

      is_binary(data) ->
        {:ok, data}

      is_map(data) ->
        { :ok, Parser.stringify(data) }

      true ->
        :error
    end
  end
end

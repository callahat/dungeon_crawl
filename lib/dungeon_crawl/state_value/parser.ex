defmodule DungeonCrawl.StateValue.Parser do
  @doc """
  Parses a key/value state string.
  State values are of the form "<key>: <value>" and comma sparated.
  Returns a tuple with the results of a successful parse, or
  an indication of an error with an invalid state string.
  It will convert the values to the proper type if able.

  ## Examples

      iex> Parser.parse("blocking: true")
      {:ok, %{blocking: true}}

      iex> Parser.parse("blocking: true, open: false, name: Wall")
      {:ok, %{blocking: true, open: false, name: "Wall"}}

      iex> Parser.parse("jibberish")
      {:error, "Error parsing around: jibberish"}
  """
  def parse!(state_string) do
    case parse(state_string) do
      {:ok, state} -> state
      {:error, msg} -> raise(msg)
    end
  end
  def parse(nil), do: {:ok, %{}}
  def parse(""),  do: {:ok, %{}}
  def parse(state_string) do
    state_string
    |> _split_and_trim(",")
    |> _key_value_pairs
  end

  defp _key_value_pairs([]), do: {:ok, %{}}

  defp _key_value_pairs([kvp | tail]) do
    case _split_and_trim(kvp, ":") do
      [_]         -> {:error, "Error parsing around: #{kvp}"}

      [key,value] ->
        case _key_value_pairs(tail) do
          {:ok, pairs}  ->
            {key, value} = _normalize_key_and_value(key, value)
            {:ok, Map.put(pairs, key, value)}
          {:error, msg} -> {:error, msg}
        end
    end
  end

  defp _split_and_trim(str, char) do
    String.split(str, char)
    |> Enum.map(fn(s) -> String.trim(s) end)
  end

  defp _normalize_key_and_value(key, value) when is_binary(key),
    do: _normalize_key_and_value(String.to_atom(key), value)
  defp _normalize_key_and_value(:equipment, value),
    do: {:equipment, String.split(value)}
  defp _normalize_key_and_value(key, value),
    do: {key, _cast_param(value)}

  defp _cast_param(param) do
    cond do
      Regex.match?(~r/^nil$/i, param) -> nil
      Regex.match?(~r/^true$/i, param) -> true
      Regex.match?(~r/^false$/i, param) -> false
      Regex.match?(~r/^-?\d+\.\d+$/, param) -> String.to_float(param)
      Regex.match?(~r/^-?\d+$/, param) -> String.to_integer(param)
      true -> param # just a string
    end
  end

  @doc """
  Turns a state map into a comma delimited string of <key>: <value> pairs.
  Returns a string.

    ## Examples

      iex> Parser.stringify(%{blocking: true})
      "blocking: true"

      iex> Parser.stringify(%{blocking: true, open: false, name: "Wall"})
      "blocking: true, name: Wall, open: false"
  """
  def stringify(state_map) do
    state_map
    |> Map.to_list
    |> Enum.map(&(_stringify_key_value(&1)))
    |> Enum.join(", ")
  end

  defp _stringify_key_value({:equipment, value}),
    do: "equipment: #{Enum.join(value, " ")}"
  defp _stringify_key_value({key, nil}),
    do: "#{key}: nil"
  defp _stringify_key_value({key, value}),
    do: "#{key}: #{value}"
end

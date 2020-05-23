defmodule DungeonCrawl.StateValue do
  @doc """
  Gets an integer from the state element matching the given key. If the key does not
  exist, or the value is not an integer, nil is returned.

  If the third parameter is supplied, that will be returned instead of nil

  ## Examples

      iex> StateValue.get_int(%{parsed_state: %{wait_cycles: 4}}, :wait_cycles)
      4

      iex> StateValue.get_int(%{parsed_state: %{facing: "west"}}, :facing)
      nil

      iex> StateValue.get_int(%{parsed_state: %{}}, :wait_cycles, 5)
      5
  """
  def get_int(object, key, default \\ nil) do
    _get_int(object.parsed_state[key], default)
  end
  def _get_int(value, _) when is_integer(value), do: value
  def _get_int(_, default), do: default

  @doc """
  Gets a boolean from the state element matching the given key. If the key does not
  exist false is returned. If the key is not false or nil, true is returned.

  ## Examples

    ie> StateValue.get_bool(%{parsed_state: %{locked: true}}, :locked)
    true

    ie> StateValue.get_bool(%{parsed_state: %{locked: nil}}, :locked)
    false

    ie> StateValue.get_bool(%{parsed_state: %{locked: yup}}, :locked)
    true

    ie> StateValue.get_bool(%{parsed_state: %{}}, :locked)
    false
  """
  def get_bool(object, key) do
    !!object.parsed_state[key]
  end
end

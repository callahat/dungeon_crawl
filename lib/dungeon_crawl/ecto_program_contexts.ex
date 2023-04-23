defmodule DungeonCrawl.EctoProgramContexts do
  @moduledoc """
  Ecto type for program contexts. The program_contexts from the level instance struct
  is very close to JSON, however some command parameters may be tuples and need
  converted to a JSON friendly list instead for the database, then converted back into a tuple
  for the level instance process and script runner.

  This seemed less of a lift than finding and rewriting all those tuples to be lists instead.
  """

  use Ecto.Type
  def type, do: :jsonb

  @tuple "__TUPLE__"

  # The program_contexts as the level_instance and processes would know it
  def cast(data) do
    cond do
      is_nil(data) || data == %{}->
        {:ok, %{}}

      _valid_param_tuples(data) ->
        {:ok, data}

      # likely won't get this one in the wild, but just in case handle it gracefully
      _valid_param_no_tuples(data) ->
        {:ok, _tuple_the_params(data)}

      true ->
        :error
    end
  end

  # change from the DB representation to how the level_instance would know it
  def load(data) do
    if _valid_param_no_tuples(data) do
      {:ok, _tuple_the_params(data)}
    else
      :error
    end
  end

  # turn the tuples into lists so program_contexts can be put into the JSONB column
  def dump(data) do
    cond do
      is_nil(data) || data == %{} ->
        {:ok, %{}}

      _valid_param_no_tuples(data) ->
        {:ok, data}

      _valid_param_tuples(data) ->
        { :ok, _convert_the_params(data) }

      true ->
        :error
    end
  end

  # Verify that any tuples in command params have not been encoded to a list
  # with first element as "__TUPLE__", but are still actual elixir tuples
  defp _valid_param_tuples(data) do
    is_map(data) &&
      Enum.all?(data, fn
        {_tile_id, %{program: program} = _program_context} ->
          Enum.all?(program.instructions, fn {_line, [_command, params]}->
            _no_list_tuples(params)
          end)

        _ ->
          false
      end)
  end

  defp _no_list_tuples(params) when is_map(params) do
    Enum.all?(params, fn {_key, value} -> _no_list_tuples(value) end)
  end
  defp _no_list_tuples([@tuple | _params]) do
    false
  end
  defp _no_list_tuples([param | params]) do
    _no_list_tuples(param) && _no_list_tuples(params)
  end
  defp _no_list_tuples(_), do: true

  # Verify that any tuples in command params have been encoded to lists
  # having the string "__TUPLE__" injected as the first element
  defp _valid_param_no_tuples(data) do
    is_map(data) &&
      Enum.all?(data, fn
        {_tile_id, %{program: program} = _program_context} ->
          Enum.all?(program.instructions, fn {_line, [_command, params]}->
            _no_tuples(params)
          end)

        _ ->
          false
      end)
  end

  defp _no_tuples(params) when is_map(params) do
    Enum.all?(params, fn {_key, value} -> _no_tuples(value) end)
  end
  defp _no_tuples(params) when is_tuple(params), do: false
  defp _no_tuples([param | params]) do
    _no_tuples(param) && _no_tuples(params)
  end
  defp _no_tuples(_), do: true

  # Converts the list encoded tuples (ie, ["__TUPLE__", ...]) back into
  # elixir tuples for the command params
  defp _tuple_the_params(data) do
    Enum.map(data, fn {tile_id, %{program: program} = program_context} ->
      instructions =
        Enum.map(program.instructions, fn {line, [command, params]}->
          {line, [command, _tuple_decode_params(params)]}
        end)
        |> Enum.into(%{})

      {tile_id, %{program_context | program: %{ program | instructions: instructions }}}
    end)
    |> Enum.into(%{})
  end

  defp _tuple_decode_params(params) when is_map(params) do
    Enum.map(params, fn {key, value} ->
      {key, _tuple_decode_params(value)}
    end)
    |> Enum.into(%{})
  end
  defp _tuple_decode_params([@tuple | params]) do
    tupled_param =
      params
      |> Enum.map(&_tuple_decode_params/1)
      |> List.to_tuple()
    tupled_param
  end
  defp _tuple_decode_params([param | params]) do
    [_tuple_decode_params(param) | _tuple_decode_params(params)]
  end
  defp _tuple_decode_params([]), do: []
  defp _tuple_decode_params(params), do: params

  # Converts the elixir tuples into encoded lists having "__TUPLE__" added
  # as the first element for the command params
  defp _convert_the_params(data) do
    Enum.map(data, fn {tile_id, %{program: program} = program_context} ->
      instructions =
        Enum.map(program.instructions, fn {line, [command, params]}->
          {line, [command, _tuple_encode_params(params)]}
        end)
        |> Enum.into(%{})

      {tile_id, %{program_context | program: %{ program | instructions: instructions }}}
    end)
    |> Enum.into(%{})
  end

  defp _tuple_encode_params(params) when is_map(params) do
    Enum.map(params, fn {key, value} ->
      {key, _tuple_encode_params(value)}
    end)
    |> Enum.into(%{})
  end
  defp _tuple_encode_params(params) when is_tuple(params) do
    [@tuple | Enum.map(Tuple.to_list(params), &_tuple_encode_params/1)]
  end
  defp _tuple_encode_params([param | params]) do
    [_tuple_encode_params(param) | _tuple_encode_params(params)]
  end
  defp _tuple_encode_params([]), do: []
  defp _tuple_encode_params(params), do: params
end

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

  alias DungeonCrawl.Scripting.Program
  alias DungeonCrawl.Player.Location

  @tuple "__TUPLE__"
  @atom "__ATOM__"

  # The program_contexts as the level_instance and processes would know it
  def cast(data) do
    cond do
      is_nil(data) || data == %{}->
        {:ok, %{}}

      _valid_program_context_as_elixir?(data) ->
        {:ok, data}

      # likely won't get this one in the wild, but just in case handle it gracefully
      _valid_program_context_as_json?(data) ->
        {:ok, _convert_to_elixir(data)}

      true ->
        :error
    end
  end

  # change from the DB representation to how the level_instance would know it
  # JSON will have all the keys as strings, but we have either integer keys or atom keys
  # for the program_contexts and their inner maps
  def load(data) do
    if _valid_program_context_as_json?(data) do
      {:ok, _convert_to_elixir(data)}
    else
      :error
    end
  end

  # turn the tuples into lists so program_contexts can be put into the JSONB column
  def dump(data) do
    cond do
      is_nil(data) || data == %{} ->
        {:ok, %{}}

      _valid_program_context_as_json?(data) ->
        {:ok, data}

      _valid_program_context_as_elixir?(data) ->
        { :ok, _convert_to_json(data) }

      true ->
        :error
    end
  end

  # Verify that any tuples in command params have not been encoded to a list
  # with first element as "__TUPLE__", but are still actual elixir tuples
  # these validations are somewhat lazy as a user should not be editing them
  defp _valid_program_context_as_elixir?(data) when is_map(data) do
    _valid_elixir?(data)
  end
  defp _valid_program_context_as_elixir?(_data), do: false

  defp _valid_elixir?(params) when is_map(params) do
    Enum.all?(Map.drop(params, [:__struct__, :__meta__]), fn
      {:labels, _} ->
        true

      {:instructions, _} ->
        true

      {:state, values} ->
        Enum.all?(values, fn {k,v} -> is_binary(k) && _valid_elixir?(v) end)

      {key, value} when is_integer(key) or is_atom(key) ->
        _valid_elixir?(value)

      _ ->
        false
    end)
  end
  defp _valid_elixir?([@tuple | _params]) do
    false
  end
  defp _valid_elixir?([@atom | _params]) do
    false
  end
  defp _valid_elixir?([param | params]) do
    _valid_elixir?(param) && _valid_elixir?(params)
  end
  defp _valid_elixir?(_), do: true

  # Verify that any tuples in command params have been encoded to lists
  # having the string "__TUPLE__" injected as the first element
  defp _valid_program_context_as_json?(data) when is_map(data) do
    _valid_json?(data)
  end
  defp _valid_program_context_as_json?(_data), do: false

  defp _valid_json?(params) when is_map(params) do
    Enum.all?(params, fn
      {"labels", _} ->
        true

      {"timed_messages", _} ->
        true

      {key, value} when is_binary(key) ->
        _valid_json?(value)

      _ ->
        false
    end)
  end
  defp _valid_json?(params) when is_boolean(params) or is_nil(params), do: true
  defp _valid_json?(params) when is_tuple(params), do: false
  defp _valid_json?(params) when is_atom(params), do: false
  defp _valid_json?([param | params]) do
    _valid_json?(param) && _valid_json?(params)
  end
  defp _valid_json?(_), do: true

  # Converts the JSON map (all keys are strings) with list encoded tuples
  # (ie, ["__TUPLE__", ...]) back into an elixir map with keys as atoms or integers
  # and the encoded list back into a tuple
  defp _convert_to_elixir(data) do
    Enum.map(data, fn {tile_id, program_context} ->
      {String.to_integer(tile_id), _decode_to_elixir(program_context, true)}
    end)
    |> Enum.into(%{})
  end

  defp _decode_to_elixir(params, atomize_keys \\ false)
  defp _decode_to_elixir(%{"calendar" => ["__ATOM__", "Elixir.Calendar.ISO"]} = params, _) do
    Enum.map(params, fn {k, v} -> {String.to_atom(k), _decode_to_elixir(v)} end)
    |> Enum.into(%{})
    |> Map.put(:__struct__, DateTime)
  end
  defp _decode_to_elixir(params, atomize_keys) when is_map(params) do
    Enum.map(params, fn
      {"event_sender", value} ->
        {:event_sender, _decode_to_elixir(value, true)}

      {"event_sender_player_location", value} ->
        # location's map needs that struct put back in
        {:event_sender, Map.merge(%Location{}, _decode_to_elixir(value, true))}

      {"program", value} ->
        # program's map needs that struct put back in
        {:program, Map.merge(%Program{}, _decode_to_elixir(value, true))}

      {"labels", value} ->
        # if its a label, nothing to do as its associated map is 1:1 going to/from json to/from elixir
        {:labels, value}

      {key, value} ->
        formatted_key = cond do
          key =~ ~r/\d+/ -> String.to_integer(key)
          atomize_keys -> String.to_atom(key)
          true -> key
        end
        {formatted_key, _decode_to_elixir(value)} # todo: this might not always (or ever) be an atom now
    end)
    |> Enum.into(%{})
  end
  defp _decode_to_elixir([@tuple | params], _) do
    tupled_param =
      params
      |> Enum.map(&_decode_to_elixir/1)
      |> List.to_tuple()
    tupled_param
  end
  defp _decode_to_elixir([@atom , param], _) do
    String.to_atom(param)
  end
  defp _decode_to_elixir([param | params], _) do
    [_decode_to_elixir(param) | _decode_to_elixir(params)]
  end
  defp _decode_to_elixir([], _), do: []
  defp _decode_to_elixir(params, _), do: params

  # Converts the elixir map into encoded lists having "__TUPLE__" added
  # as the first element for the command params
  defp _convert_to_json(data) do
    Enum.map(data, fn {tile_id, program_context} ->
      {to_string(tile_id), _encode_to_json(program_context)}
    end)
    |> Enum.into(%{})
  end

  @drop_for_json_encode [:__struct__, :__meta__, :tile, :inserted_at, :updated_at]

  defp _encode_to_json(params) when is_map(params) do
    # these drops might not be on the map; but don't readily convert to JSON
    # `tile` makes the list beacuse sometimes %Location{} will be given as the event
    # sender and `tile` is not preloaded, so we don't want or need it.
    # Add other non preloaded fields (or uneeded fields with hard to code/decode values
    # such as timestamps) to this drop list if encountered and not actually needed.
    Enum.map(Map.drop(params, @drop_for_json_encode), fn {key, value} ->
      encoded_key = if key == :event_sender && value && Map.get(value, :__struct__) == Location,
                       do: "event_sender_player_location",
                       else: to_string(key)
      {encoded_key, _encode_to_json(value)}
    end)
    |> Enum.into(%{})
  end
  defp _encode_to_json(param) when is_boolean(param) or is_nil(param) do
    param
  end
  defp _encode_to_json(params) when is_tuple(params) do
    [@tuple | Enum.map(Tuple.to_list(params), &_encode_to_json/1)]
  end
  defp _encode_to_json(param) when is_atom(param) do
    [@atom, to_string(param)]
  end
  defp _encode_to_json([param | params]) do
    [_encode_to_json(param) | _encode_to_json(params)]
  end
  defp _encode_to_json([]), do: []
  defp _encode_to_json(params), do: params
end

defmodule DungeonCrawl.EventResponder.Parser do
  @word "[A-Za-z_\-]+?"

  @doc """
  Parses a binary representation of event responders.
  Returns a tuple with the results of a successful parse, or
  an indication that the given representation is invalid.

  It accepts binaries/strings that follow the grammar:

  expression  => {<event_pairs>}
  event_pairs => <event_pair>
                 <event_pair>,<event_pairs>
  event_pair  => <event>:<result>
  result      => {:<status>,<callbacks>}
  callbacks   => <callback>
                 <callback>,<callbacks>
  callback    => <action>:[<params>]
  params      => <param>
                 <param>,<params>

  param, status, action, event, all being terminals.
  status, action, event matching [A-Za-z_\-]+,
  and param being able to contain other characters.

  ## Examples

      iex> Parser.parse("{move: {:ok}}")
      {:ok, %{move: {:ok}}}

      iex> Parser.parse("{move: {:ok}, close: {:ok, replace: [123]}}")
      {:ok, %{move: {:ok}, close: {:ok, %{replace: [123]}}}}

      iex> Parser.parse("jibberish}")
      {:error, "Problem parsing", "jibberish}"}

      iex> Parser.parse("{open: {:ok, replace: 1234}}")
      {:error, "Problem parsing callbacks", " replace: 1234"}
  """
  def parse(event_responder) do
    case Regex.named_captures(~r/\A{(?<event_pairs>.+)}\z/ms, String.trim(event_responder)) do
      %{"event_pairs" => event_pairs} ->
        case _parse_event_pairs(event_pairs) do
          {:ok, parsed_event_pairs} -> {:ok, parsed_event_pairs}
          error                     -> error
        end

      nil -> {:error, "Problem parsing", event_responder}
    end
  end

  defp _parse_event_pairs(given_event_pairs) do
    case Regex.named_captures(~r/\A(?<event_pair>#{@word}:\s*{.+?})(?:,(?<event_pairs>.+))?\z/ms, String.trim(given_event_pairs)) do
      %{"event_pair" => event_pair, "event_pairs" => ""} ->
        case _parse_event_pair(event_pair) do
          {:ok, parsed_event_pair} -> {:ok, parsed_event_pair}
          error                    -> error
        end

      %{"event_pair" => event_pair, "event_pairs" => event_pairs} ->
        case _parse_event_pairs(event_pairs) do
          {:ok, parsed_event_pairs} ->
            case _parse_event_pair(event_pair) do
              {:ok, parsed_event_pair} -> {:ok, Map.merge(parsed_event_pairs, parsed_event_pair)}
              error                    -> error
            end

          error -> error
        end

      nil -> {:error, "Problem parsing event pairs", given_event_pairs}
    end
  end

  defp _parse_event_pair(given_event_pair) do
    case Regex.named_captures(~r/\A(?<event_name>#{@word}):\s*(?<result>.+)\z/ms, String.trim(given_event_pair)) do
      %{"event_name" => _event_name, "result" => ""}     -> {:error, given_event_pair}
      %{"event_name" => event_name,  "result" => result} ->
            case _parse_result(result) do
              {:ok, parsed_result} -> {:ok, %{ String.to_atom(event_name) => parsed_result }}
              error                -> error
            end

      nil                                                -> {:error, given_event_pair}
    end
  end

  defp _parse_result(result) do
    case Regex.named_captures(~r/\A{\s*:(?<status>#{@word})(?:,(?<callbacks>.+))?}\z/ms, String.trim(result)) do
      %{"status" => status, "callbacks" => ""}        -> {:ok, {String.to_atom(status)} }

      %{"status" => status, "callbacks" => callbacks} ->
        case _parse_callbacks(callbacks) do
          {:ok, parsed_callbacks} -> {:ok, {String.to_atom(status), parsed_callbacks} }
          error                   -> error
        end

      nil                                             -> {:error, "Problem parsing event results", result}
    end
  end

  defp _parse_callbacks(given_callbacks) do
    case Regex.named_captures(~r/\A(?<callback>#{@word}:\s*\[.+?\])(?:\s*,(?<callbacks>.+))?\z/ms, String.trim(given_callbacks)) do
      %{"callback" => callback, "callbacks" => ""}        ->
        case _parse_callback(callback) do
          {:ok, parsed_callback} -> {:ok, parsed_callback}
          error                  -> error
        end

      %{"callback" => callback, "callbacks" => callbacks} -> 
        case _parse_callbacks(callbacks) do
          {:ok, parsed_callbacks} ->
            case _parse_callback(callback) do
              {:ok, parsed_callback} -> {:ok, Map.merge(parsed_callbacks, parsed_callback)}
              error                  -> error
            end

          error                      -> error
        end

      nil                            -> {:error, "Problem parsing callbacks", given_callbacks}
    end
  end

  defp _parse_callback(callback) do
    case Regex.named_captures(~r/\A(?<word>#{@word}):\s*\[(?<params>.+)\]\z/ms, String.trim(callback)) do
      # lazy way of getting the parameters, may need to make it better later as text with a comma will mess it up
      %{"word" => word, "params" => params} -> {:ok, %{ String.to_atom(word) => _parse_params(params) } }

      nil                                   -> {:error, "Problem parsing callback", callback}
    end
  end

  defp _parse_params(params) do
    params
    |> String.trim
    |> String.split(",")
    |> Enum.map(&(String.trim(&1)))
    |> Enum.map(&_cast_param(&1))
  end

  defp _cast_param(param) do
    cond do
      Regex.match?(~r/^\d+$/, param) -> String.to_integer(param)
      Regex.match?(~r/^\d+\.\d+$/, param) -> String.to_float(param)
      Regex.match?(~r/^:./, param) -> String.to_existing_atom(param) # Might not even need this one
      true -> param
    end
  end
end

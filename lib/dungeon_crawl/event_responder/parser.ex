defmodule DungeonCrawl.EventResponder.Parser do
  @word "[A-Za-z_\-]+?"

  @doc """
  Parses a binary representation of event responders.
  Returns a tuple with the results of a successful parse, or
  an indication that the given representation is invalid.

  ## Examples

      iex> Parser.parse("{move: {:ok}}")
      {:ok, %{move: {:ok}}}

      iex> Parser.parse("{move: {:ok}, close: {:ok, replace: [123]}}")
      {:ok, %{move: {:ok}, close: {:ok, %{replace: [123]}}}}

      iex> Parser.parse("{jibberish}")
      {:error, "jibberish"}
  """
  def parse(event_responder) do
    case Regex.named_captures(~r/\A{(?<events>.+)}\z/ms, String.trim(event_responder)) do
      %{"events" => events} -> 
        case _parse_events(events) do
          {:ok, parsed_events} -> {:ok, parsed_events}
          error               -> error
        end
      nil                   -> {:error, event_responder}
    end
  end

  defp _parse_events(given_events) do
IO.puts "_parse_events"
IO.puts given_events
    case Regex.named_captures(~r/\A(?<event>#{@word}:\s*{.+?})(?:,(?<events>.+))?\z/ms, String.trim(given_events)) do
      %{"event" => event, "events" => ""}     -> 
        case _parse_event(event) do
          {:ok, parsed_event} -> {:ok, parsed_event}
          error               -> error
        end

      %{"event" => event, "events" => events} -> 
        case _parse_events(events) do
          {:ok, parsed_events} -> 
            case _parse_event(event) do
              {:ok, parsed_event} -> {:ok, Map.merge(parsed_events, parsed_event)}
              error               -> error
            end

          error               -> error
        end

      nil                                     -> {:error, given_events}
    end
  end

  defp _parse_event(given_event) do
IO.puts "_parse_event"
IO.puts given_event
    case Regex.named_captures(~r/\A(?<event_name>#{@word}):\s*(?<result>.+)\z/ms, String.trim(given_event)) do
      %{"event_name" => event_name, "result" => ""}     -> {:error, given_event}
      %{"event_name" => event_name, "result" => result} -> #{:ok, %{ String.to_atom(event_name) => _parse_result(result) }}
            case _parse_result(result) do
              {:ok, parsed_result} -> {:ok, %{ String.to_atom(event_name) => parsed_result }}
              error               -> error
            end

      nil                                   -> {:error, given_event}
    end
  end

  defp _parse_result(result) do
IO.puts "_parse_result"
IO.puts result
    case Regex.named_captures(~r/\A{\s*:(?<status>#{@word})(?:,(?<callbacks>.+))?}\z/ms, String.trim(result)) do
      %{"status" => status, "callbacks" => ""}        -> {:ok, {String.to_atom(status)} }

      %{"status" => status, "callbacks" => callbacks} -> 
        case _parse_callbacks(callbacks) do
          {:ok, parsed_callbacks} -> {:ok, {String.to_atom(status), parsed_callbacks} }
          error                   -> error
        end

      nil                                             -> {:error, result}
    end
  end

  defp _parse_callbacks(given_callbacks) do
IO.puts "_parse_callbacks"
IO.puts given_callbacks
    case Regex.named_captures(~r/\A(?<callback>#{@word}:\s*\[.+?\])(?:\s*,(?<callbacks>.+))?\z/ms, String.trim(given_callbacks)) do
      %{"callback" => callback, "callbacks" => ""}     -> 
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

      nil                            -> {:error, given_callbacks}
    end
  end

  defp _parse_callback(callback) do
IO.puts "_parse_callback"
IO.puts callback
    case Regex.named_captures(~r/\A(?<word>#{@word}):\s*\[(?<params>.+)\]\z/ms, String.trim(callback)) do
      # lazy way of getting the parameters, may need to make it better later as text with a comma will mess it up
      %{"word" => word, "params" => params} -> {:ok, %{ String.to_atom(word) => _parse_params(params) } }

      nil                                   -> {:error, callback}
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

defmodule DungeonCrawl.EventResponder.Parser do
  @doc """
  Parses a binary representation of event responders.
  Returns a tuple with the results of a successful parse, or
  an indication that the given representation is invalid.

  ## Examples

      iex> parse("{move: {:ok}, close: {:ok, replace: [123]}}")
      {:ok, %{move: {:ok}, close: {:ok, %{replace: [123]}}}}

      iex> get_map_tile!("{jibberish}")
      {:error}
  """
  def parse(event_responder) do
    case Regexp.named_captures(~r/\A{(?<events>.+)}\z/ms, String.trim(event_responder)) do
      %{"events" => events} -> _parse_events(events, %{})
      nil                   -> {:error, event_responder}
    end
  end

  defp _parse_events(given_events, parsed_events) do
    case Regex.named_captures(~r/\A(?<event>.+?:\s*{.+?})(?:,(?<events>.+))?\z/ms, String.trim(given_events)) do
      %{"event" => event, "events" => ""}     -> _parse_event(event, parsed_events)

      %{"event" => event, "events" => events} -> 
        case _parse_events(events, parsed_events) do
          {:ok, parsed_events} -> 
            case _parse_event(event) do
              {:ok, parsed_event} -> Map.merge(parsed_events, parsed_event)
              error               -> error
            end

          error               -> error
        end

      nil                                     -> {:error, given_events}
    end
  end

  defp _parse_event(given_event) do
    case Regex.named_captures(~r/\A(?<word>[A-Za-z_\-]+?):\s*(?<result>.+)\z/ms, String.trim(given_event)) do
      %{"word" => word, "result" => ""}     -> {:error, given_event}
      %{"word" => word, "result" => result} -> _parse_result(word, result, parsed_events)
      nil                                   -> {:error, given_event}
    end
  end

  defp _parse_result(word, result) do
    case Regexp.named_captures(~r/\A{\s*:(?<status>.+?)(?:,(?<callbacks>))?}\z/ms, String.trim(result)) do
      %{"status" => status, "callbacks" => ""}        -> %{ word => {status.to_sym} }

      %{"status" => status, "callbacks" => callbacks} -> 
        case _parse_callbacks(callbacks) do
          {:ok, parsed_callbacks} -> %{ word => {status.to_sym, parsed_callbacks} }
          error                   -> error
        end

      nil                                             -> {:error, result}
    end
  end

  defp _parse_callbacks(callbacks) do
    case Regex.named_captures(~r/\A(?<callback>.+?:\s*[.+?])(?:\s*,(?<callbacks>.+))?\z/ms, String.trim(callbacks)) do
      %{"callback" => callback, "callbacks" => ""}     -> _parse_callback(callback)

      %{"callback" => callback, "callbacks" => callbacks} -> 
        case _parse_callbacks(callbacks) do
          {:ok, parsed_callbacks} -> 
            case _parse_callback(callback) do
              {:ok, parsed_callback} -> Map.merge(parsed_callbacks, parsed_callback)
              error                  -> error
            end

          error                      -> error
        end

      nil                            -> {:error, callbacks}
    end
  end

end

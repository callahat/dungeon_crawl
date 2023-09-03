defmodule DungeonCrawl.Shipping.JsonTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Shipping.DungeonExports

  alias DungeonCrawl.Shipping.Json

  describe "encode/1" do
    test "encodes the map" do
      assert "{\"test\":{\"string==\":\"yes\",\"subject\":true}}"
             == Json.encode!(%{test: %{subject: true, "string==": "yes"}})
    end

    test "errors on bad input" do
      assert_raise Protocol.UndefinedError, ~r"Jason.Encoder not implemented for {} of type Tuple,", fn ->
        Json.encode!({})
      end
    end
  end

  describe "decode!/1" do
    test "decodes the json" do
      assert %DungeonExports{dungeon: %{name: "yes", active: true}}
             == Json.decode!("{\"dungeon\":{\"name\":\"yes\",\"active\":true}}")
    end

    test "errors on bad input" do
      assert_raise Jason.DecodeError, ~r"unexpected byte at position", fn ->
        Json.decode!("{\"test\": missing paren")
      end
    end
  end

  test "encode! to decode! and back" do
    export = DungeonCrawlWeb.ExportFixture.export
    json = Json.encode!(export)

    assert json == Json.encode!(Json.decode!(json))
    assert export == _atomize_state_keys(Json.decode!(json))
  end

  # This is needed because internally, the state values are atoms, however Json decode
  # will stringify the keys (since they are not in @atoms).
  # Remove this should the state values ever be changed from atoms to strings.

  #  iex(12)> Jason.encode %{bob: 2}
  #  {:ok, "{\"bob\":2}"}
  #  iex(13)> Jason.encode %{"bob" => 2}
  #  {:ok, "{\"bob\":2}"}
  defp _atomize_state_keys(json) when is_map(json) do
    json
    |> Map.to_list()
    |> _atomize_state_keys()
    |> Enum.into(%{})
  end
  defp _atomize_state_keys([]), do: []
  defp _atomize_state_keys([{:state, values} | json]) do
    atomized = Enum.map(values, fn {key, value} -> {String.to_atom(key), value} end)
               |> Enum.into(%{})
    [
      {:state, atomized} | _atomize_state_keys(json)
    ]
  end
  defp _atomize_state_keys([{key, value} | json]) do
    recursed = _atomize_state_keys(value)
    [
      {key, recursed} | _atomize_state_keys(json)
    ]
  end
  defp _atomize_state_keys(terminal_value), do: terminal_value
end

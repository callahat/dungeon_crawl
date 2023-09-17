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
    assert export == Json.decode!(json)
  end
end

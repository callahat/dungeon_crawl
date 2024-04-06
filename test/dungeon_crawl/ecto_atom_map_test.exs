defmodule DungeonCrawl.EctoStateValueMapTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoAtomMap

  describe "type" do
    assert EctoAtomMap.type == :jsonb
  end

  describe "cast/1" do
    test "returns error when its invalid" do
      assert EctoAtomMap.cast([{"123", "junk"}]) == :error
      assert EctoAtomMap.cast([123, "junk"]) == :error
      assert EctoAtomMap.cast("moo") == :error
    end

    test "returns ok and a map when valid" do
      assert EctoAtomMap.cast(nil) == {:ok, %{}}
      assert EctoAtomMap.cast(%{one: :two}) == {:ok, %{one: :two}}
      assert EctoAtomMap.cast(%{"one" => :two}) == {:ok, %{one: :two}}
    end
  end

  describe "load/1" do
    test "loads data that should be valid" do
      assert EctoAtomMap.load(nil) == {:ok, %{}}
      assert EctoAtomMap.load(%{one: :two}) == {:ok, %{one: :two}}
      assert EctoAtomMap.load(%{"one" => :two}) == {:ok, %{one: :two}}
    end

    test "doesnt load corrupt data" do
      assert EctoAtomMap.load(12345) == :error
      # should never have invalid data in the DB
      assert EctoAtomMap.load("someone edited this...") == :error
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert EctoAtomMap.dump(456) == :error
      assert EctoAtomMap.dump([%{1 => "key"}]) == :error
    end

    test "lets the good data in" do
      assert EctoAtomMap.dump(nil) == {:ok, %{}}
      assert EctoAtomMap.dump(%{}) == {:ok, %{}}
      assert EctoAtomMap.dump(%{one: "two", three: "five"}) ==
               {:ok, %{one: "two", three: "five"}}
    end
  end
end

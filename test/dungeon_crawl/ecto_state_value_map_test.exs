defmodule DungeonCrawl.EctoStateValueMapTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoStateValueMap

  describe "type" do
    assert EctoStateValueMap.type == :string
  end

  describe "cast/1" do
    test "returns error when its invalid" do
      assert EctoStateValueMap.cast([{"123", "junk"}]) == :error
      assert EctoStateValueMap.cast([123, "junk"]) == :error
      assert EctoStateValueMap.cast({1, []}) == :error
    end

    test "returns ok and a map when valid" do
      assert EctoStateValueMap.cast(nil) == {:ok, %{}}
      assert EctoStateValueMap.cast(%{one: :two}) == {:ok, %{one: :two}}
      assert EctoStateValueMap.cast("one: two, three: five, equipment: 1 2 3") ==
               {:ok, %{one: "two", three: "five", equipment: ["1", "2", "3"]}}
    end
  end

  describe "load/1" do
    test "loads data that should be valid" do
      assert EctoStateValueMap.load("one: two, three: five, equipment: 1 2 3") ==
               {:ok, %{one: "two", three: "five", equipment: ["1", "2", "3"]}}
    end

    test "doesnt load corrupt data" do
      assert EctoStateValueMap.load(12345) == :error
      # should never have invalid data in the DB
      assert_raise RuntimeError, ~r"Error parsing around: someone edited this...", fn ->
        EctoStateValueMap.load("someone edited this...")
      end
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert EctoStateValueMap.dump(456) == :error
      assert EctoStateValueMap.dump([%{1 => "key"}]) == :error
    end

    test "lets the good data in" do
      assert EctoStateValueMap.dump(nil) == {:ok, nil}
      assert EctoStateValueMap.dump(%{}) == {:ok, nil}
      assert EctoStateValueMap.dump("one: two, three: five, equipment: 1 2 3") ==
               {:ok, "one: two, three: five, equipment: 1 2 3"}
      assert EctoStateValueMap.dump(%{one: "two", three: "five", equipment: ["1", "2", "3"]}) ==
               {:ok, "equipment: 1 2 3, one: two, three: five"}
    end
  end
end

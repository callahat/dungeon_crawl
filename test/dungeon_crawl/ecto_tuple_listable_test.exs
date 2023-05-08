defmodule DungeonCrawl.EctoTupleListableTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoTupleListable

  defmodule TestModule do
    use EctoTupleListable, [&is_integer/1, &is_binary/1]
  end

  describe "cast/1" do
    test "returns error when its invalid" do
      assert TestModule.cast("junk") == :error
      assert TestModule.cast([{"123", "junk"}]) == :error
      assert TestModule.cast([123, "junk"]) == :error
      assert TestModule.cast(%{123 => "key"}) == :error
      assert TestModule.cast({1, "key"}) == :error
      assert TestModule.cast({1, []}) == :error
    end

    test "returns ok and a list when valid" do
      assert TestModule.cast(nil) == {:ok, []}
      assert TestModule.cast([{1,"key"}]) == {:ok, [{1, "key"}]}
      assert TestModule.cast([[1,"key"]]) == {:ok, [{1, "key"}]}
      assert TestModule.cast([{143,"key"},{2,"gray"}]) == {:ok, [{143, "key"}, {2, "gray"}]}
    end
  end

  describe "load/1" do
    test "loads data that should be valid" do
      assert TestModule.load([[143, "key"], [2, "gray"]]) == {:ok, [{143, "key"}, {2, "gray"}]}
    end

    test "doesnt load corrupt data" do
      assert TestModule.load("someone edited this...") == :error
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert TestModule.dump("someone edited this...") == :error
      assert TestModule.dump([%{1 => "key"}]) == :error
    end

    test "lets the good data in" do
      assert TestModule.dump([[143, "key"], [2, "gray"]]) == {:ok, [[143, "key"], [2, "gray"]]}
      assert TestModule.dump([[1, "key"]]) == {:ok, [[1, "key"]]}
      assert TestModule.dump([{1, "key"}]) == {:ok, [[1, "key"]]}
    end
  end
end

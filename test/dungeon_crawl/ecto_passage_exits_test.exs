defmodule DungeonCrawl.EctoPassageExitsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EctoPassageExits

  describe "cast/1" do
    test "returns error when its invalid" do
      assert EctoPassageExits.cast(nil) == :error
      assert EctoPassageExits.cast("junk") == :error
      assert EctoPassageExits.cast([{"123", "junk"}]) == :error
      assert EctoPassageExits.cast([123, "junk"]) == :error
      assert EctoPassageExits.cast(%{123 => "key"}) == :error
      assert EctoPassageExits.cast("{1, key}") == :error
      assert EctoPassageExits.cast("{1,}") == :error
    end

    test "returns ok and a list of tuples when valid" do
      assert EctoPassageExits.cast("{1,key}") == {:ok, [{1, "key"}]}
      assert EctoPassageExits.cast("{143,key},{2,gray}") == {:ok, [{143, "key"}, {2, "gray"}]}
    end
  end

  describe "load/1" do
    test "loads data that should be valid" do
      assert EctoPassageExits.load("{143,key},{2,gray}") == {:ok, [{143, "key"}, {2, "gray"}]}
    end

    test "doesnt load corrupt data" do
      assert EctoPassageExits.load("someone edited this...") == :error
    end
  end

  describe "dump/1" do
    test "doesn't dump bad data to the database" do
      assert EctoPassageExits.dump("someone edited this...") == :error
    end

    test "lets the good data in" do
      assert EctoPassageExits.dump([{143, "key"}, {2, "gray"}]) == {:ok, "{143,key},{2,gray}"}
      assert EctoPassageExits.dump([{1, "key"}]) == {:ok, "{1,key}"}
    end
  end
end

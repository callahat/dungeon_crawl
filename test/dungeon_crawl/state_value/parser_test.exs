defmodule DungeonCrawl.StateValue.ParserTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.StateValue.Parser

  doctest Parser

  describe "parse" do
    test "no state items" do
      assert {:ok, %{}} == Parser.parse(nil)
      assert {:ok, %{}} == Parser.parse("")
    end

    test "one state item" do
      assert {:ok, %{blocking: true}} == Parser.parse("blocking: true")
    end

    test "many state items with different types" do
      assert {:ok, %{blocking: false, health: 98.6, foo: 3, neg: -1, name: "BobJohntrue"}} ==
             Parser.parse("blocking: false, health: 98.6, foo: 3, neg: -1, name: BobJohntrue")
    end

    test "bad state string" do
      assert {:error, "Error parsing around: blaaahhhh"} == Parser.parse("blocking: true, blaaahhhh, good: false")
    end
  end

  describe "stringify" do
    test "empty map" do
      assert "" == Parser.stringify(%{})
    end

    test "map with one item" do
      assert "wall: true" == Parser.stringify(%{wall: true})
    end

    test "map with several items" do
      assert "a: 1, b: two, d: false, pasta: spaghetti" == Parser.stringify(%{a: 1, b: "two", d: false, pasta: "spaghetti"})
    end
  end
end

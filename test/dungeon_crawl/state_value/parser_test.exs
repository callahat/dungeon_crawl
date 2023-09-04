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

    test "state item that is equipment" do
      assert {:ok, %{equipment: ["hand", "saw", "pickaxe"]}} == Parser.parse("equipment: hand saw pickaxe")
    end

    test "state item that is starting_equipment" do
      assert {:ok, %{starting_equipment: ["a", "c", "b"]}} == Parser.parse("starting_equipment: a c b")
    end
  end

  describe "parse!" do
    test "returns the valid parsed state" do
      assert %{blocking: true} == Parser.parse!("blocking: true")
      assert %{} == Parser.parse!(nil)
    end

    test "raises exception when state is invalid" do
      assert_raise RuntimeError, fn -> Parser.parse!(",,") end
    end
  end

  describe "stringify" do
    test "empty map" do
      assert "" == Parser.stringify(%{})
    end

    test "empty nil" do
      assert "" == Parser.stringify(nil)
    end

    test "map with one item" do
      assert "wall: true" == Parser.stringify(%{wall: true})
    end

    test "map with several items" do
      assert "a: 1, b: two, d: false, pasta: spaghetti" == Parser.stringify(%{a: 1, b: "two", d: false, pasta: "spaghetti"})
    end

    test "map with equipment" do
      assert "equipment: file cabinet" == Parser.stringify(%{equipment: ["file", "cabinet"]})
    end

    test "map with starting_equipment" do
      assert "starting_equipment: file cabinet" == Parser.stringify(%{starting_equipment: ["file", "cabinet"]})
    end
  end
end

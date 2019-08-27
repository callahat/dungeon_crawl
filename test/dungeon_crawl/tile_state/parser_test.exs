defmodule DungeonCrawl.TileState.ParserTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileState.Parser

  doctest Parser

  test "no state items" do
    assert {:ok, %{}} == Parser.parse(nil)
    assert {:ok, %{}} == Parser.parse("")
  end

  test "one state item" do
    assert {:ok, %{blocking: true}} == Parser.parse("blocking: true")
  end

  test "many state items with different types" do
    assert {:ok, %{blocking: false, health: 98.6, foo: 3, name: "BobJohntrue"}} == Parser.parse("blocking: false, health: 98.6, foo: 3, name: BobJohntrue")
  end

  test "bad state string" do
    assert {:error, "Error parsing around: blaaahhhh"} == Parser.parse("blocking: true, blaaahhhh, good: false")
  end
end

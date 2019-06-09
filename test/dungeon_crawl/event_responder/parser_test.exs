defmodule DungeonCrawl.EventResponder.ParserTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.EventResponder.Parser

  doctest Parser

  test "no events" do
    assert {:ok, %{}} = Parser.parse("{}")
  end

  test "one event but no callbacks" do
    assert {:ok, %{move: {:ok}}} = Parser.parse("{move: {:ok}}")
  end

  test "one event with callbacks without params" do
    assert {:ok, %{kick: {:ok, %{damage: []}}}} = Parser.parse("{kick: {:ok, damage: []}}")
  end

  test "one event with callbacks" do
    assert {:ok, %{open: {:ok, %{replace: [123456]}}}} = Parser.parse("{open: {:ok, replace: [123456]}}")
  end

  test "one event with callbacks, many params" do
    assert {:ok, %{open: {:ok, %{replace: [123456, 111222]}}}} = Parser.parse("{open: {:ok, replace: [123456, 111222]}}")
  end

  test "two events with callbacks, many params" do
    assert {:ok, %{open: {:ok, %{replace: [123456, 111222]}},
                   burn: {:ok, %{text: ["It burns"], damage: []}}}} = Parser.parse("{open: {:ok, replace: [123456, 111222]}, 
                                                                                     burn: {:ok, text: [It burns], damage: []}}")
  end

end

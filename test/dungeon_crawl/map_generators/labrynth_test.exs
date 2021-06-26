defmodule DungeonCrawl.MapGenerators.LabrynthTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.MapGenerators.Labrynth

  test "generate returns a map with a rol, col tuple as key and tile as value" do
    dungeon_map = Labrynth.generate(20,20)
    [first_key | _other_keys] = Map.keys dungeon_map

    assert is_map(dungeon_map)
    assert {row, col} = first_key
    assert is_integer(row)
    assert is_integer(col)
  end

  test "generate returns a map stairs up" do
    dungeon_map = Labrynth.generate(20,20,true)
    assert Enum.find(dungeon_map, fn {_, char} -> char == ?▟ end)
  end
end

defmodule DungeonCrawl.DungeonGeneratorTest do
  use DungeonCrawlWeb.ModelCase

  alias DungeonCrawl.DungeonGenerator

  test "generate returns a map with a rol, col tuple as key and tile as value" do
    dungeon_map = DungeonGenerator.generate(20,20)
    [first_key | _other_keys] = Map.keys dungeon_map

    assert is_map(dungeon_map)
    assert {row, col} = first_key
    assert is_integer(row)
    assert is_integer(col)
  end

  test "stringify returns a printable representation of the dungeon" do
    str = DungeonGenerator.generate(20,20) |> DungeonGenerator.stringify(20)
    assert is_binary(str)
  end
end

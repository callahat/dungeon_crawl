defmodule DungeonCrawl.MapGenerators.UtilsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.MapGenerators.ConnectedRooms
  alias DungeonCrawl.MapGenerators.Utils

  test "stringify returns a printable representation of the dungeon" do
    str = ConnectedRooms.generate(20,20) |> Utils.stringify(20)
    assert is_binary(str)
  end
end

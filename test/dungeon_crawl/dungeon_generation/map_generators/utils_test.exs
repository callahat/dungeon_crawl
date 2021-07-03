defmodule DungeonCrawl.DungeonGeneration.MapGenerators.UtilsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRooms
  alias DungeonCrawl.DungeonGeneration.MapGenerators.Utils

  test "stringify returns a printable representation of the level" do
    str = ConnectedRooms.generate(20,20) |> Utils.stringify(20)
    assert is_binary(str)
  end
end

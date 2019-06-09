defmodule DungeonCrawl.TileTemplates.TileSeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates.TileSeeder

  test "basic_tiles returns the same map on subsequent calls" do
    assert  %{?. => _, ?# => _, ?\s => _, ?' => _, ?+ => _, ?@ => statue,
              "." => _, "#" => _, " " => _, "'" => _, "+" => _, "@" => statue} = basic_tiles = TileSeeder.basic_tiles()
    assert basic_tiles == TileSeeder.basic_tiles()
  end

  test "basic_tiles returns the map where the string and character code reference the same tile template" do
    basic_tiles = TileSeeder.basic_tiles()
    assert basic_tiles[?.]  == basic_tiles["."]
    assert basic_tiles[?#]  == basic_tiles["#"]
    assert basic_tiles[?\s] == basic_tiles[" "]
    assert basic_tiles[?']  == basic_tiles["'"]
    assert basic_tiles[?+]  == basic_tiles["+"]
    assert basic_tiles[?@]  == basic_tiles["@"]
  end
end

defmodule DungeonCrawl.TileTemplates.TileSeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates.TileSeeder

  test "basic_tiles returns the same map on subsequent calls" do
    assert  %{?. => _, ?# => _, ?\s => _, ?' => _, ?+ => _, ?@ => _} = basic_tiles = TileSeeder.basic_tiles()
    assert basic_tiles == TileSeeder.basic_tiles()
  end
end

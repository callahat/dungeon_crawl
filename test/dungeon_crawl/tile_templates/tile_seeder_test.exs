defmodule DungeonCrawl.TileTemplates.TileSeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.TileTemplates.TileSeeder
  alias DungeonCrawl.TileTemplates.TileTemplate

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

  test "bullet and player character tiles" do
    assert bullet_tile = TileSeeder.bullet_tile()
    assert player_character_tile = TileSeeder.player_character_tile()
    refute is_nil(bullet_tile.id)
    refute is_nil(player_character_tile.id)
  end

  test "color_keys_and_doors" do
    assert :ok = TileSeeder.color_keys_and_doors
    ["red", "green", "blue", "gray", "purple", "orange"]
    |> Enum.each(fn color ->
         color_key = "#{color} key"
         color_door = "#{color} door"
         assert Repo.one(from tt in TileTemplate, where: tt.name == ^color_key)
         assert Repo.one(from tt in TileTemplate, where: tt.name == ^color_door)
       end)

    assert TileSeeder.generic_colored_key
    assert TileSeeder.generic_colored_door
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Colored Key")
    assert Repo.one(from tt in TileTemplate, where: tt.name == "Colored Door")
  end
end

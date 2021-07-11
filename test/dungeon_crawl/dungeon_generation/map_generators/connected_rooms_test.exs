defmodule DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRoomsTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonGeneration.Entities
  alias DungeonCrawl.DungeonGeneration.MapGenerators.ConnectedRooms

  test "generate returns a map with a rol, col tuple as key and tile as value" do
    dungeon_map = ConnectedRooms.generate(20,20)
    [first_key | _other_keys] = Map.keys dungeon_map

    assert is_map(dungeon_map)
    assert {row, col} = first_key
    assert is_integer(row)
    assert is_integer(col)
  end

  @tag timeout: 1_000
  test "generate returns a map with stairs up" do
    dungeon_map = ConnectedRooms.generate(20,20, 1)
    assert Enum.find(dungeon_map, fn {_, char} -> char == ?▟ end)
  end

  test "_treasure_room/2" do
    connected_rooms = %ConnectedRooms{
      cave_height: 5,
      cave_width: 5,
      map: %{
        {0, 0} => ?#, {0, 1} => ?#, {0, 2} => ?#, {0, 3} => ?#, {0, 4} => ?#,
        {1, 0} => ?#, {1, 1} => ?., {1, 2} => ?., {1, 3} => ?., {1, 4} => ?#,
        {2, 0} => ?#, {2, 1} => ?., {2, 2} => ?., {2, 3} => ?x, {2, 4} => ?#,
        {3, 0} => ?#, {3, 1} => ?., {3, 2} => ?., {3, 3} => ?., {3, 4} => ?#,
        {4, 0} => ?#, {4, 1} => ?#, {4, 2} => ?#, {4, 3} => ?#, {4, 4} => ?# }
     }
     coords = %{bottom_right_col: 4, bottom_right_row: 4, top_left_col: 0, top_left_row: 0}
     %{map: map} = ConnectedRooms._treasure_room(connected_rooms, coords)
     assert %{
        {0, 0} => ?#, {0, 1} => ?#, {0, 2} => ?#, {0, 3} => ?#, {0, 4} => ?#,
        {1, 0} => ?#, {1, 1} =>  _, {1, 2} =>  _, {1, 3} =>  _, {1, 4} => ?#,
        {2, 0} => ?#, {2, 1} =>  _, {2, 2} =>  _, {2, 3} => ?x, {2, 4} => ?#,
        {3, 0} => ?#, {3, 1} =>  _, {3, 2} =>  _, {3, 3} =>  _, {3, 4} => ?#,
        {4, 0} => ?#, {4, 1} => ?#, {4, 2} => ?#, {4, 3} => ?#, {4, 4} => ?# } = map
     assert Enum.member?(Entities.treasures, map[{1, 1}])
     assert Enum.member?(Entities.treasures, map[{1, 2}])
     assert Enum.member?(Entities.treasures, map[{1, 3}])
     assert Enum.member?(Entities.treasures, map[{2, 1}])
     assert Enum.member?(Entities.treasures, map[{2, 2}])
     assert Enum.member?(Entities.treasures, map[{3, 1}])
     assert Enum.member?(Entities.treasures, map[{3, 2}])
     assert Enum.member?(Entities.treasures, map[{3, 3}])
  end
end

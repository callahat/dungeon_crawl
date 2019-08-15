defmodule DungeonCrawl.MapGenerators.TestRooms do
  @cave_height 20
  @cave_width  20

  def random_dungeon_render() do
"""
#################   
#...............#   
#...............#   
#@..............#   
######'##########   
    #..........#    
    #..........#    
    #..........#    
    #..........#    
    #..........#    
    #..........#    
    #..........#    
    #..........#    
    #####+##########
    #..............#
    #..............#
    #..............#
    #..............#
    ################
                    
"""
  end

  # Generates a random test dungeon
  def generate(_cave_height \\ @cave_height, _cave_width \\ @cave_width) do
    random_dungeon_render()
    |> String.split("\n") 
    |> Enum.with_index
    |> Enum.reduce(%{}, fn({cols, row}, acc) -> 
         cols
         |> String.to_charlist
         |> Enum.with_index
         |> Enum.reduce(acc,fn({tile, col}, acc) -> 
              Map.put(acc,{row,col}, tile) 
         end)
    end)
  end
end

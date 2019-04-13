defmodule DungeonCrawl.DungeonGenerator.TestRooms do
  @cave_height 20
  @cave_width  20

  # Generates a random test dungeon
  def generate(_cave_height \\ @cave_height, _cave_width \\ @cave_width) do
    dungeon = """
#################   
#...............#   
#...............#   
#...............#   
######'##########   
    #..........#    
    #.........@#    
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
    dungeon
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

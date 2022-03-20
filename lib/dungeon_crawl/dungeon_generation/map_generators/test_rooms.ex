defmodule DungeonCrawl.DungeonGeneration.MapGenerators.TestRooms do
  @cave_height 21
  @cave_width  21

  def random_level_render() do
"""
#################    
#.........ϴ.....#    
#....♂..........#    
#...............#    
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
    #.............?# 
    #..............# 
    #..............# 
    #..............# 
    ################ 
                     
                     
"""
  end

  # Generates a random test level
  def generate(_cave_height \\ @cave_height, _cave_width \\ @cave_width, solo_level \\ nil) do
    random_level_render()
    |> String.replace("?", if(solo_level, do: "▟", else: "."))
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

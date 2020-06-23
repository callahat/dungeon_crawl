defmodule DungeonCrawl.TileTemplates.TileSeeder.Creatures do
  alias DungeonCrawl.TileTemplates

  def expanding_foam do
    TileTemplates.find_or_create_tile_template!(
      %{character: "*",
        name: "Expanding Foam",
        description: "It gets all over",
        state: "blocking: true, range: 7, wait_cycles: 3",
        color: "green",
        public: true,
        active: true,
        script: """
                @range -= 1
                #IF @range == 0, done
                ?i
                #IF ?north@blocking, south
                #PUT slug: expanding_foam, direction: north, color: @color, range: @range
                :south
                #IF ?south@blocking, east
                #PUT slug: expanding_foam, direction: south, color: @color, range: @range
                :east
                #IF ?east@blocking, west
                #PUT slug: expanding_foam, direction: east, color: @color, range: @range
                :west
                #IF ?west@blocking, done
                #PUT slug: expanding_foam, direction: west, color: @color, range: @range
                :done
                #BECOME slug: breakable_wall, color: @color
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def expanding_foam(), do: unquote(__MODULE__).expanding_foam()
    end
  end
end

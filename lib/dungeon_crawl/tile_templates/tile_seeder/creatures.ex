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

  def pede_head do
    TileTemplates.find_or_create_tile_template!(
      %{character: "ϴ",
        name: "PedeHead",
        description: "Centipede head",
        state: "blocking: true, facing: south",
        public: true,
        active: true,
        script: """
                :main
                #pull @facing
                #if ?{@facing}@blocking, thud
                #send main
                #end
                :thud
                #if not ?clockwise@blocking,not_surrounded
                #if not ?counterclockwise@blocking,not_surrounded
                #send surrounded
                #end
                :not_surrounded
                #facing clockwise
                #send main
                #end
                :shot
                #facing reverse
                #send pede_died, @facing
                #die
                #end
                :surrounded
                #facing reverse
                #send surrounded, @facing
                #become slug: pedebody, color: @color, background_color: @background_color
                """
    })
  end

  def pede_body do
    TileTemplates.find_or_create_tile_template!(
      %{character: "O",
        name: "PedeBody",
        description: "Centipede body segment",
        state: "pullable: map_tile_id, pulling: true, blocking: true, facing: west",
        public: true,
        active: true,
        script: """
                #end
                :shot
                #facing reverse
                #send pede_died, @facing
                ?i
                #die
                :pede_died
                #become slug: pedehead, facing: @facing, pullable: false, color: @color, background_color: @background_color
                #end
                :surrounded
                #facing reverse
                @pullable = map_tile_id
                #if @facing == west, checkwest
                #if @facing == south, checksouth
                #if @facing == north, checknorth
                :checkeast
                #if ?east@name == PedeBody, not_tail
                #send tail
                :checkwest
                #if ?west@name == PedeBody, not_tail
                #send tail
                :checksouth
                #if ?south@name == PedeBody, not_tail
                #send tail
                :checknorth
                #if ?north@name == PedeBody, not_tail
                :tail
                #become slug: pedehead, facing: @facing, pullable: false, color: @color, background_color: @background_color
                #end
                :not_tail
                #send surrounded, @facing
                #end
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def expanding_foam(), do: unquote(__MODULE__).expanding_foam()
      def pede_head(), do: unquote(__MODULE__).pede_head()
      def pede_body(), do: unquote(__MODULE__).pede_body()
    end
  end
end

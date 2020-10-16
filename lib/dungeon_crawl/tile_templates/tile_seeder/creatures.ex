defmodule DungeonCrawl.TileTemplates.TileSeeder.Creatures do
  alias DungeonCrawl.TileTemplates

  def bandit do
    TileTemplates.update_or_create_tile_template!(
      "bandit",
      %{character: "♣",
        name: "Bandit",
        description: "It runs around",
        state: "blocking: true, soft: true, destroyable: true, pushable: true",
        color: "maroon",
        public: true,
        active: true,
        script: """
                :THUD
                :NEW_SPEED
                #RANDOM wait_cycles, 2-5
                :NEW_DIRECTION
                #RANDOM direction, north, south, east, west, player, player
                #RANDOM steps, 2-5
                :MOVING
                #IF ?{@facing}@player, HURT_PLAYER
                #TRY @direction
                @steps -= 1
                #IF @steps > 0, MOVING
                #IF ?random@4 == 1, NEW_SPEED
                #SEND NEW_DIRECTION
                #END
                :TOUCH
                #IF not ?sender@player, NEW_DIRECTION
                #TAKE health, 10, ?sender
                #DIE
                :HURT_PLAYER
                #TAKE health, 10, @facing
                #DIE
                """
    })
  end

  def expanding_foam do
    TileTemplates.update_or_create_tile_template!(
      "expanding_foam",
      %{character: "*",
        name: "Expanding Foam",
        description: "It gets all over",
        state: "blocking: true, soft: true, range: 7, wait_cycles: 3",
        color: "green",
        public: true,
        active: true,
        script: """
                @range -= 1
                #IF @range == 0, done
                ?i
                #IF ! ?north@blocking
                #PUT slug: expanding_foam, direction: north, color: @color, range: @range
                #IF ! ?south@blocking
                #PUT slug: expanding_foam, direction: south, color: @color, range: @range
                #IF ! ?east@blocking
                #PUT slug: expanding_foam, direction: east, color: @color, range: @range
                #IF ! ?west@blocking
                #PUT slug: expanding_foam, direction: west, color: @color, range: @range
                :done
                #BECOME slug: breakable_wall, color: @color
                """
    })
  end

  def pede_head do
    TileTemplates.update_or_create_tile_template!(
      "pedehead",
      %{character: "ϴ",
        name: "PedeHead",
        description: "Centipede head",
        state: "blocking: true, soft: true, facing: south, pulling: map_tile_id",
        public: true,
        active: true,
        script: """
                :main
                #pull @facing
                #if ?{@facing}@blocking, thud
                #send main
                #end
                :thud
                #if ?sender@player, hurt_player
                #if ?{@facing}@player, hurt_player
                #if @pulling == false, not_surrounded
                #if not ?clockwise@blocking,not_surrounded
                #if not ?counterclockwise@blocking,not_surrounded
                #if not ?reverse@blocking,not_surrounded
                #send surrounded
                #end
                :not_surrounded
                #facing clockwise
                #send main
                #end
                :shot
                :bombed
                #lock
                #send pede_died, @pulling
                #die
                #end
                :surrounded
                #facing reverse
                #send surrounded, @pulling
                #become slug: pedebody, color: @color, background_color: @background_color, pulling: false, pullable: @pulling
                #end
                :touch
                #if not ?sender@player, main
                #lock
                #take health, 10, ?sender
                #send pede_died, @pulling
                #die
                :hurt_player
                #take health, 10, @facing
                #send pede_died, @pulling
                #die
                """
    })
  end

  def pede_body do
    TileTemplates.update_or_create_tile_template!(
      "pedebody",
      %{character: "O",
        name: "PedeBody",
        description: "Centipede body segment",
        state: "pullable: map_tile_id, pulling: map_tile_id, blocking: true, soft: true, facing: west",
        public: true,
        active: true,
        script: """
                #end
                :shot
                :bombed
                #lock
                #send pede_died, @pulling
                #die
                :surrounded
                #facing reverse
                #if @pulling != false, not_tail
                :tail
                #become slug: pedehead, facing: @facing, color: @color, background_color: @background_color, pullable: false, pulling: @pullable
                #end
                :pede_died
                #become slug: pedehead, facing: @facing, color: @color, background_color: @background_color, pullable: false, pulling: @pulling
                #end
                :not_tail
                @tmp = @pulling
                @pulling = @pullable
                @pullable = @tmp
                #send surrounded, @pullable
                #end
                :touch
                #if not ?sender@player, done
                #lock
                #take health, 10, ?sender
                #send pede_died, @pulling
                #die
                :done
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def bandit(), do: unquote(__MODULE__).bandit()
      def expanding_foam(), do: unquote(__MODULE__).expanding_foam()
      def pede_head(), do: unquote(__MODULE__).pede_head()
      def pede_body(), do: unquote(__MODULE__).pede_body()
    end
  end
end

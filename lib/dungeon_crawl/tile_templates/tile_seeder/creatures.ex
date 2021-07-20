defmodule DungeonCrawl.TileTemplates.TileSeeder.Creatures do
  alias DungeonCrawl.TileTemplates

  def bandit do
    TileTemplates.update_or_create_tile_template!(
      "bandit",
      %{character: "♣",
        name: "Bandit",
        description: "It runs around",
        state: "blocking: true, soft: true, destroyable: true, pushable: true, points: 5",
        color: "maroon",
        public: true,
        active: true,
        group_name: "monsters",
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

  def bear do
    TileTemplates.update_or_create_tile_template!(
      "bear",
      %{character: "ö",
        name: "Bear",
        description: "They hibernate this time of year",
        state: "int: 4, range: 5, blocking: true, soft: true, destroyable: true, pushable: true, awake: false, points: 5",
        color: "brown",
        public: true,
        active: true,
        group_name: "monsters",
        script: """
                :top
                #target_player nearest
                #if @awake, sniffed
                :listening
                #if ?{@target_player_map_tile_id}@distance <= @range, sniffed
                @awake = false
                #send top
                #end
                :sniffed
                #random move_dir, north, south, east, west
                #if ?random@10 <= @int
                @move_dir = player
                #try @move_dir
                #if ?{@facing}@player, hurt_player
                #if ?{@target_player_map_tile_id}@distance > @range, 2
                #if ?random@4 == 1
                @awake = false
                ?i
                #send top
                #end
                :touch
                #if not ?sender@player, top
                #take health, 10, ?sender
                #die
                :hurt_player
                #take health, 10, @facing
                #die
                :thud
                #if ?sender@name==Breakable Wall, 2
                #send shot, ?sender
                #die
                ?i
                #send top
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
        group_name: "monsters",
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

  def grid_bug do
    TileTemplates.update_or_create_tile_template!(
      "grid_bug",
      %{character: "x",
        name: "Grid Bug",
        description: "Zap!",
        state: "blocking: true, soft: true, destroyable: true, points: 6, split_rate: 1, not_pushing: true",
        color: "purple",
        public: true,
        active: true,
        group_name: "monsters",
        animate_period: 10,
        animate_characters: "+, x",
        script: """
                :top
                #random move_dir, north, south, east, west
                #try @move_dir
                #if ?random@10 <= @split_rate, split
                :idle
                /i
                #send top
                #end
                :touch
                :thud
                #if not ?sender@player, idle
                #take health, 10, ?sender
                #die
                :split
                #if ?{@move_dir}@blocking, idle
                #put slug: grid_bug, direction: @move_dir
                #send top
                """
    })
  end

  def lion do
    TileTemplates.update_or_create_tile_template!(
      "lion",
      %{character: "Ω",
        name: "Lion",
        description: "Hear its mighty roar",
        state: "int: 4, blocking: true, soft: true, destroyable: true, pushable: true, points: 10",
        color: "darkorange",
        public: true,
        active: true,
        group_name: "monsters",
        script: """
                :top
                #target_player nearest
                #random move_dir, north, south, east, west
                #if ?random@10 <= @int
                @move_dir = player
                #try @move_dir
                #if ?{@facing}@player, hurt_player
                #send top
                #end
                :touch
                #if not ?sender@player, top
                #take health, 10, ?sender
                #die
                :hurt_player
                #take health, 10, @facing
                #die
                """
    })
  end

  def pede_head do
    TileTemplates.update_or_create_tile_template!(
      "pedehead",
      %{character: "ϴ",
        name: "PedeHead",
        description: "Centipede head",
        state: "blocking: true, soft: true, facing: south, pulling: centipede, centipede: true",
        public: true,
        active: true,
        group_name: "monsters",
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
                #give score, 5, ?sender@owner
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
        state: "pullable: centipede, pulling: centipede, blocking: true, soft: true, facing: west, centipede: true",
        public: true,
        active: true,
        group_name: "monsters",
        script: """
                #end
                :shot
                :bombed
                #lock
                #send pede_died, @pulling
                #give score, 3, ?sender@owner
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

  def rockworm do
    TileTemplates.update_or_create_tile_template!(
      "rockworm",
      %{character: "r",
        name: "Rockworm",
        description: "Sharp teeth and tough hide, burrowing through the stone",
        state: "blocking: true, soft: true, health: 50, wait_cycles: 4, points: 30, not_pushing: true",
        color: "gray",
        public: true,
        active: true,
        group_name: "monsters",
        script: """
                :top
                #random move_dir, north, south, east, west
                :wander
                #if ?random@5 == 1, top
                #try @move_dir
                :rest
                ?i
                #send wander
                #end
                :thud
                #if ?sender@player, hitplayer
                #if ?sender@low, top
                #if ! ?sender@id, void
                #replace target_id: ?sender, slug: floor
                #send rest
                #end
                :void
                #if ?random@4 == 1, top
                #put direction: @facing, slug: floor
                #send rest
                #end
                :hitplayer
                #take health, 10, ?sender
                #send rest
                """
    })
  end

  def tiger do
    TileTemplates.update_or_create_tile_template!(
      "tiger",
      %{character: "π",
        name: "Tiger",
        description: "Cunning and swift, a prince of the jungle",
        state: "int: 4, wis: 7, gun: 5, blocking: true, soft: true, destroyable: true, pushable: true, wait_cycles: 3, points: 10",
        color: "teal",
        public: true,
        active: true,
        group_name: "monsters",
        script: """
                :top
                #target_player nearest
                #random move_dir, north, south, east, west
                #if ?random@10 <= @int
                @move_dir = player
                #try @move_dir
                #if ?{@facing}@player, hurt_player
                #if ?random@10 <= @gun, shoot
                #send top
                #end
                :touch
                #if not ?sender@player, top
                #take health, 10, ?sender
                #die
                :hurt_player
                #take health, 10, @facing
                #die
                :shoot
                #random shoot_dir, north, south, east, west
                #if ?random@10 <= @wis
                @shoot_dir = player
                #shoot @shoot_dir
                #send top
                """
    })
  end

  def zombie do
    TileTemplates.update_or_create_tile_template!(
      "zombie",
      %{character: "@",
        name: "Zombie",
        description: "Consumed by a mindless hunger",
        state: "blocking: true, soft: true, hits: 3, pushable: true",
        color: "green",
        public: true,
        active: true,
        group_name: "monsters",
        script: """
                #cycle 8
                :top
                #target_player nearest
                #random move_dir, north, south, east, west
                #if ?random@10 <= 9
                @move_dir = player
                #try @move_dir
                #if ?{@facing}@player, hurt_player
                #send top
                #end
                :touch
                #if not ?sender@player, top
                #take health, 10, ?sender
                /i
                #send top
                #end
                :hurt_player
                #take health, 10, @facing
                /i
                #send top
                #end
                :shot
                #if ?sender@owner == enemy, top
                @hits--
                @who = ?sender@owner
                #if @hits < 1, dead
                /i
                #send top
                #end
                :dead
                #give score, 20, @who
                #die
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def bandit(), do: unquote(__MODULE__).bandit()
      def bear(), do: unquote(__MODULE__).bear()
      def expanding_foam(), do: unquote(__MODULE__).expanding_foam()
      def grid_bug(), do: unquote(__MODULE__).grid_bug()
      def lion(), do: unquote(__MODULE__).lion()
      def pede_head(), do: unquote(__MODULE__).pede_head()
      def pede_body(), do: unquote(__MODULE__).pede_body()
      def rockworm(), do: unquote(__MODULE__).rockworm()
      def tiger(), do: unquote(__MODULE__).tiger()
      def zombie(), do: unquote(__MODULE__).zombie()
    end
  end
end

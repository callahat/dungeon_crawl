defmodule DungeonCrawl.TileTemplates.TileSeeder.Ordinance do
  alias DungeonCrawl.TileTemplates

  def bomb do
    TileTemplates.update_or_create_tile_template!(
      "bomb",
      %{character: "♂",
        name: "Bomb",
        description: "A bomb. Better not touch it, looks dangerous.",
        state: "blocking: true, bomb_damage: 20, counter: 9, pushable: true, soft: true, blocking_light: false",
        color: "black",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                #IF @fuse_lit, FUSE_LIT
                #END
                :TOUCH
                #ZAP TOUCH
                #IF ?sender@player, FUSE_LIT
                #RESTORE TOUCH
                #END
                :FUSE_LIT
                #ZAP TOUCH
                #IF @owner, 1
                @owner = ?sender@id
                #BECOME character: @counter
                Ssssss.....
                :TOP
                ?i?i
                @counter -= 1
                #BECOME character: @counter
                #IF @counter <= 0, BOOM
                #SEND TOP
                #END
                :BOMBED
                @owner = ?sender@owner
                :BOOM
                #SOUND bomb
                #PUT slug: explosion, shape: circle, range: 6, damage: @bomb_damage, owner: @owner
                #DIE
                """
    })
  end

  def fireball() do
    TileTemplates.update_or_create_tile_template!(
      "fireball",
      %{character: "◦",
        name: "Fireball",
        description: "Its a bullet.",
        state: "blocking: false, wait_cycles: 2, not_pushing: true, not_squishing: true, flying: true, light_source: true, light_range: 2",
        color: "orange",
        active: true,
        script: """
        :MAIN
        #WALK @facing
        :THUD
        #SOUND bomb
        #PUT slug: explosion, shape: circle, range: 2, damage: 10, owner: @owner
        #DIE
        """
      })
  end

  def explosion do
    TileTemplates.update_or_create_tile_template!(
      "explosion",
      %{character: "▒",
        name: "Explosion",
        description: "Caught up in the explosion",
        state: "count: 3, damage: 10, light_source: true, light_range: 1",
        color: "crimson",
        public: true, # TODO: should this be false? would that prevent others from using the slug even though its standard?
        active: true,
        group_name: "misc",
        script: """
                #SEND bombed, here
                :TOP
                #RANDOM c, red, orange, yellow
                #BECOME color: @c
                ?i
                @count -= 1
                #IF @count > 0, top
                #DIE
                """
    })
  end

  def smoke do
    TileTemplates.update_or_create_tile_template!(
      "smoke",
      %{character: "▒",
        name: "Smoke",
        description: "Fine particles of various dust and gas",
        state: "blocking: false, duration: 20, smoke: true",
        color: "gray",
        public: true,
        active: true,
        group_name: "misc",
        script: """
                @counter = 0
                :wait
                @counter += 1
                #IF @counter >= @duration, fading
                #SEND wait
                ?i
                :fading
                @counter = 0
                #ZAP wait
                #BECOME character: ░
                :wait
                @counter += 1
                #IF @counter >= @duration, fading
                #SEND wait
                ?i
                :done
                #DIE
                """
    })
  end

  def star() do
    TileTemplates.update_or_create_tile_template!(
      "star",
      %{character: "/",
        name: "Star",
        description: "Its going to get you.",
        public: true,
        active: true,
        group_name: "misc",
        animate_period: 1,
        animate_characters: "|, \\, -, /",
        animate_colors: "red, green, darkorange, blue, purple",
        state: "range: 50, damage: 10, facing: north, wait_cycles: 4, blocking: true, not_pushing: true, not_squishing: true, flying: true, light_source: true, light_range: 1, blocking_light: false",
        script: """
                #target_player random
                :top
                #facing player
                ?p
                #restore touch
                #restore thud
                #send spinning
                #end
                :touch
                :thud
                #zap touch
                #zap thud
                #if ?sender@name == Star, shoot
                #if ?sender@name == Breakable Wall, shoot
                #if ?sender@player, shoot
                /i
                :spinning
                @range -= 1
                #if @range > 0, top
                #die
                #end
                :shoot
                #send shot, ?sender
                #die
                """
      })
  end

  def star_emitter() do
    TileTemplates.update_or_create_tile_template!(
      "star_emitter",
      %{character: "┼",
        name: "Star Emitter",
        description: "Shoots stars",
        public: true,
        active: true,
        group_name: "misc",
        state: "star_range: 50, star_damage: 10, wait_cycles: 100, blocking: true",
        script: """
                :top
                #put direction: here, slug: star, range: @star_range, damage: @star_damage
                /i
                #send top
                """
      })
  end

  defmacro __using__(_params) do
    quote do
      def bomb(), do: unquote(__MODULE__).bomb()
      def explosion(), do: unquote(__MODULE__).explosion()
      def fireball(), do: unquote(__MODULE__).fireball()
      def smoke(), do: unquote(__MODULE__).smoke()
      def star(), do: unquote(__MODULE__).star()
      def star_emitter(), do: unquote(__MODULE__).star_emitter()
    end
  end
end

defmodule DungeonCrawl.TileTemplates.TileSeeder.Ordinance do
  alias DungeonCrawl.TileTemplates

  def bomb do
    TileTemplates.update_or_create_tile_template!(
      "bomb",
      %{character: "♂",
        name: "Bomb",
        description: "A bomb. Better not touch it, looks dangerous.",
        state: "blocking: true, bomb_damage: 20, counter: 9",
        color: "black",
        public: true,
        active: true,
        script: """
                #END
                :TOUCH
                #ZAP TOUCH
                #IF ?sender@player, FUSE_LIT
                #RESTORE TOUCH
                #END
                :FUSE_LIT
                #BECOME character: @counter
                Ssssss.....
                :TOP
                ?i?i
                @counter -= 1
                #BECOME character: @counter
                #IF @counter <= 0, BOOM
                #SEND TOP
                #END
                :BOOM
                #PUT slug: explosion, shape: circle, range: 6, damage: @bomb_damage
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
        state: "count: 3, damage: 10",
        color: "crimson",
        public: true,
        active: true,
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

  defmacro __using__(_params) do
    quote do
      def bomb(), do: unquote(__MODULE__).bomb()
      def explosion(), do: unquote(__MODULE__).explosion()
      def smoke(), do: unquote(__MODULE__).smoke()
    end
  end
end

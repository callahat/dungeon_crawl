defmodule DungeonCrawl.TileTemplates.TileSeeder.Terrain do
  alias DungeonCrawl.TileTemplates

  def boulder() do
    TileTemplates.update_or_create_tile_template!(
      "boulder",
      %{character: "▪",
        name: "Boulder",
        description: "A smooth boulder",
        state: "blocking: true, pushable: true, pullable: true",
        public: true,
        active: true
    })
  end

  def counter_clockwise_conveyor() do
    TileTemplates.update_or_create_tile_template!(
      "counter_clockwise_conveyor",
      %{character: "/",
        name: "Counter Clockwise Conveyor",
        description: "Rotates things around it in a counter clockwise direction",
        state: "blocking: true, wait_cycles: 2",
        public: true,
        active: true,
        script: """
                :top
                /i
                #SHIFT counterclockwise
                #SEQUENCE char, |, \\, -, /
                #BECOME character: @char
                #send top
                """
    })
  end

  def clockwise_conveyor() do
    TileTemplates.update_or_create_tile_template!(
      "clockwise_conveyor",
      %{character: "\\",
        name: "Clockwise Conveyor",
        description: "Rotates things around it in a clockwise direction",
        state: "blocking: true, wait_cycles: 2",
        public: true,
        active: true,
        script: """
                :top
                /i
                #SHIFT clockwise
                #SEQUENCE char, |, /, -, \\
                #BECOME character: @char
                #send top
                """
    })
  end

  def forest() do
    TileTemplates.update_or_create_tile_template!(
      "forest",
      %{character: "▓",
        name: "Forest",
        description: "A thick forest",
        state: "blocking: true",
        color: "green",
        public: true,
        active: true,
        script: """
                #end
                :touch
                #if ! ?sender@player, DONE
                #become character: ░, blocking: false
                You blaze a trail
                #terminate
                :done
                """
    })
  end

  def junk_pile() do
    TileTemplates.update_or_create_tile_template!(
      "junk_pile",
      %{character: "Д",
        name: "Junk Pile",
        description: "Just a pile of junk, maybe some of its useful.",
        state: "blocking: false",
        color: "gray",
        background_color: "linen",
        public: false,
        active: true,
    })
  end

  def lava() do
    TileTemplates.update_or_create_tile_template!(
      "lava",
      %{character: "░",
        name: "Lava",
        description: "Its molten rock",
        state: "blocking: true, low: true, soft: true, wait_cycles: 20",
        color: "black",
        background_color: "red",
        public: true,
        active: true,
        script: """
                :main
                #random char, ▒, ░, ░
                #random bc, red, red, darkorange, orange
                #become character: @char, background_color: @bc
                /i
                #send main
                #end
                :touch
                #if ! ?sender@player, main
                That lava looks hot, better not touch it.
                #send main
                """
    })
  end

  def grave() do
    TileTemplates.update_or_create_tile_template!(
      "grave",
      %{character: "✝",
        name: "Grave",
        description: "It looks fresh. R.I.P.",
        state: "blocking: false",
        public: false,
        active: true,
    })
  end

  def ricochet() do
    TileTemplates.update_or_create_tile_template!(
      "ricochet",
      %{character: "*",
        name: "Ricochet",
        description: "Projectiles might bounce off this, watch out",
        state: "ricochet: true, blocking: true",
        public: true,
        active: true,
    })
  end

  def slider_horizontal() do
    TileTemplates.update_or_create_tile_template!(
      "slider_horizontal",
      %{character: "↔",
        name: "Slider Horizontal",
        description: "It can be moved north and south",
        state: "blocking: true, pushable: ew",
        public: true,
        active: true
    })
  end

  def slider_vertical() do
    TileTemplates.update_or_create_tile_template!(
      "slider_vertical",
      %{character: "↕",
        name: "Slider Vertical",
        description: "It can be moved north and south",
        state: "blocking: true, pushable: ns",
        public: true,
        active: true
    })
  end

  defmacro __using__(_params) do
    quote do
      def boulder(), do: unquote(__MODULE__).boulder()
      def counter_clockwise_conveyor(), do: unquote(__MODULE__).counter_clockwise_conveyor()
      def clockwise_conveyor(), do: unquote(__MODULE__).clockwise_conveyor()
      def forest(), do: unquote(__MODULE__).forest()
      def junk_pile(), do: unquote(__MODULE__).junk_pile()
      def lava(), do: unquote(__MODULE__).lava()
      def grave(), do: unquote(__MODULE__).grave()
      def ricochet(), do: unquote(__MODULE__).ricochet()
      def slider_horizontal(), do: unquote(__MODULE__).slider_horizontal()
      def slider_vertical(), do: unquote(__MODULE__).slider_vertical()
    end
  end
end

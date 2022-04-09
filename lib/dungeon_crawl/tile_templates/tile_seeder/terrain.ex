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
        active: true,
        group_name: "terrain"
    })
  end

  def counter_clockwise_conveyor() do
    TileTemplates.update_or_create_tile_template!(
      "counter_clockwise_conveyor",
      %{character: "/",
        name: "Counter Clockwise Conveyor",
        description: "Rotates things around it in a counter clockwise direction",
        state: "blocking: true, wait_cycles: 2, blocking_light: false",
        public: true,
        active: true,
        group_name: "misc",
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
        state: "blocking: true, wait_cycles: 2, blocking_light: false",
        public: true,
        active: true,
        group_name: "misc",
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
        group_name: "terrain",
        script: """
                #end
                :touch
                #if ! ?sender@player, DONE
                #become character: ░, blocking: false
                You blaze a trail
                #sound trudge
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
        public: true,
        active: true,
        unlisted: true,
    })
  end

  def lava() do
    TileTemplates.update_or_create_tile_template!(
      "lava",
      %{character: "░",
        name: "Lava",
        description: "Its molten rock",
        state: "blocking: true, low: true, soft: true, light_source: true, light_range: 2",
        color: "black",
        background_color: "red",
        public: true,
        active: true,
        group_name: "terrain",
        animate_random: true,
        animate_period: 10,
        animate_characters: "▒, ░, ░",
        animate_background_colors: "red, red, darkorange, orange",
        script: """
                #end
                :touch
                #if ?sender@player
                That lava looks hot, better not touch it.
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
        public: true,
        active: true,
        unlisted: true
    })
  end

  def ricochet() do
    TileTemplates.update_or_create_tile_template!(
      "ricochet",
      %{character: "*",
        name: "Ricochet",
        description: "Projectiles might bounce off this, watch out",
        state: "ricochet: true, blocking: true, blocking_light: false",
        public: true,
        active: true,
        group_name: "terrain"
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
        active: true,
        group_name: "terrain"
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
        active: true,
        group_name: "terrain"
    })
  end

  def water() do
    TileTemplates.update_or_create_tile_template!(
      "water",
      %{character: "░",
        name: "Water",
        description: "Its wet",
        state: "blocking: true, low: true, soft: true",
        color: "white",
        background_color: "blue",
        public: true,
        active: true,
        group_name: "terrain",
        animate_random: false,
        animate_period: 5,
        animate_characters: "░, ▒, ░, "
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
      def water(), do: unquote(__MODULE__).water()
    end
  end
end

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
                /i
                :top
                #SHIFT counterclockwise
                #BECOME character: |
                /i
                #SHIFT counterclockwise
                #BECOME character: \\
                /i
                #SHIFT counterclockwise
                #BECOME character: -
                /i
                #SHIFT counterclockwise
                #BECOME character: /
                /i
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
                /i
                :top
                #SHIFT clockwise
                #BECOME character: |
                /i
                #SHIFT clockwise
                #BECOME character: /
                /i
                #SHIFT clockwise
                #BECOME character: -
                /i
                #SHIFT clockwise
                #BECOME character: \\
                /i
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

  defmacro __using__(_params) do
    quote do
      def boulder(), do: unquote(__MODULE__).boulder()
      def counter_clockwise_conveyor(), do: unquote(__MODULE__).counter_clockwise_conveyor()
      def clockwise_conveyor(), do: unquote(__MODULE__).clockwise_conveyor()
      def forest(), do: unquote(__MODULE__).forest()
      def grave(), do: unquote(__MODULE__).grave()
      def ricochet(), do: unquote(__MODULE__).ricochet()
    end
  end
end

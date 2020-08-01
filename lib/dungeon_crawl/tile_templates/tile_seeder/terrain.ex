defmodule DungeonCrawl.TileTemplates.TileSeeder.Terrain do
  alias DungeonCrawl.TileTemplates

  def boulder() do
    TileTemplates.find_or_create_tile_template!(
      %{character: "▪",
        name: "Boulder",
        description: "A boulder",
        state: "blocking: true, pushable: true, pullable: true",
        public: true,
        active: true
    })
  end

  def counter_clockwise_conveyor() do
    TileTemplates.find_or_create_tile_template!(
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
    TileTemplates.find_or_create_tile_template!(
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

  def grave() do
    TileTemplates.find_or_create_tile_template!(
      %{character: "✝",
        name: "Grave",
        description: "It looks fresh. R.I.P.",
        state: "blocking: false",
        public: false,
        active: true,
    })
  end

  defmacro __using__(_params) do
    quote do
      def boulder(), do: unquote(__MODULE__).boulder()
      def counter_clockwise_conveyor(), do: unquote(__MODULE__).counter_clockwise_conveyor()
      def clockwise_conveyor(), do: unquote(__MODULE__).clockwise_conveyor()
      def grave(), do: unquote(__MODULE__).grave()
    end
  end
end

defmodule DungeonCrawl.TileTemplates.TileSeeder.BlockWalls do
  alias DungeonCrawl.TileTemplates

  def solid_wall() do
    TileTemplates.update_or_create_tile_template!(
      "solid_wall",
      %{character: "█",
        name: "Solid Wall",
        description: "A solid wall",
        state: "blocking: true",
        public: true,
        active: true,
        group_name: "terrain"
    })
  end

  def normal_wall() do
    TileTemplates.update_or_create_tile_template!(
      "normal_wall",
      %{character: "▒",
        name: "Normal Wall",
        description: "A normal wall",
        state: "blocking: true",
        public: true,
        active: true,
        group_name: "terrain"
    })
  end

  def breakable_wall() do
    TileTemplates.update_or_create_tile_template!(
      "breakable_wall",
      %{character: "░",
        name: "Breakable Wall",
        description: "A breakable wall",
        state: "blocking: true, destroyable: true, soft: true",
        public: true,
        active: true,
        group_name: "terrain"
    })
  end

  def fake_wall() do
    TileTemplates.update_or_create_tile_template!(
      "fake_wall",
      %{character: "▒",
        name: "Fake Wall",
        description: "A fake wall",
        state: "blocking: true",
        public: true,
        active: true,
        group_name: "terrain",
        script: """
                #END
                :TOUCH
                #IF ! ?sender@player, DONE
                #LOCK
                #SOUND heal
                You discover a secret passage!
                :FOUND
                @blocking = false
                #SEND FOUND, north
                #SEND FOUND, south
                #SEND FOUND, east
                #SEND FOUND, west
                #TERMINATE
                :DONE
                """
    })
  end

  def invisible_wall() do
    TileTemplates.update_or_create_tile_template!(
      "invisible_wall",
      %{character: ".",
        name: "Invisible Wall",
        description: "An invisible wall",
        state: "blocking: true",
        public: true,
        active: true,
        group_name: "terrain",
        script: """
                #end
                :touch
                #if ! ?sender@player, DONE
                #become character: ▒
                Oof, you bump into something
                #terminate
                :done
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def solid_wall(), do: unquote(__MODULE__).solid_wall()
      def normal_wall(), do: unquote(__MODULE__).normal_wall()
      def breakable_wall(), do: unquote(__MODULE__).breakable_wall()
      def fake_wall(), do: unquote(__MODULE__).fake_wall()
      def invisible_wall(), do: unquote(__MODULE__).invisible_wall()
    end
  end
end

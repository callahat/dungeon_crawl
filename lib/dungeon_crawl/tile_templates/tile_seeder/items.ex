defmodule DungeonCrawl.TileTemplates.TileSeeder.Items do
  alias DungeonCrawl.TileTemplates

  def ammo do
    TileTemplates.update_or_create_tile_template!(
      "ammo",
      %{character: "ä",
        name: "Ammo",
        description: "A box of ammo",
        state: "pushable: true",
        color: "olivedrab",
        public: true,
        active: true,
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                You found some ammo
                #give ammo, 6, ?sender
                #die
                :shot
                :bombed
                #put slug: explosion, shape: circle, range: 2, damage: 5
                #die
                """
    })
  end

  def cash do
    TileTemplates.update_or_create_tile_template!(
      "cash",
      %{character: "$",
        name: "Cash",
        description: "Dollar bills",
        state: "destroyable: true, pushable: true",
        color: "green",
        background_color: "black",
        public: true,
        active: true,
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                Dolla bills, make it rain
                #random cash, 5-10
                #give cash, @cash, ?sender
                #die
                """
    })
  end

  def gem do
    TileTemplates.update_or_create_tile_template!(
      "gem",
      %{character: "♦",
        name: "Gem",
        description: "Gem",
        state: "destroyable: true, blocking: true, soft: true, pushable: true",
        color: "blue",
        public: true,
        active: true,
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                You found a gem!
                #give gems, 1, ?sender
                #die
                """
    })
  end

  def heart do
    TileTemplates.update_or_create_tile_template!(
      "heart",
      %{character: "♥",
        name: "Heart",
        description: "A heart",
        state: "pushable: true",
        color: "red",
        public: true,
        active: true,
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                Restored some health
                #give health, 10, ?sender, 100
                #die
                """
    })
  end

  def medkit do
    TileTemplates.update_or_create_tile_template!(
      "medkit",
      %{character: "✚",
        name: "MedKit",
        description: "A medical kit",
        state: "pushable: true",
        color: "red",
        background_color: "white",
        public: true,
        active: true,
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                This will stop the bleeding
                #give health, 50, ?sender, 100
                #die
                """
    })
  end

  def scroll do
    TileTemplates.update_or_create_tile_template!(
      "scroll",
      %{character: "ɸ",
        name: "Scroll",
        description: "Add your own text for this item",
        state: "pushable: true, wait_cycles: 2",
        public: true,
        active: true,
        script: """
                :main
                #random c, red, orange, yellow,cyan, magenta, blue, white, green, purple, darkcyan, darkred
                #become color: @c
                /i
                #send main
                #end
                :touch
                #if ! ?sender@player, main
                ** YOUR TEXT HERE **
                   yup right here
                #die
                """
    })
  end

  defmacro __using__(_params) do
    quote do
      def ammo(), do: unquote(__MODULE__).ammo()
      def cash(), do: unquote(__MODULE__).cash()
      def gem(), do: unquote(__MODULE__).gem()
      def heart(), do: unquote(__MODULE__).heart()
      def medkit(), do: unquote(__MODULE__).medkit()
      def scroll(), do: unquote(__MODULE__).scroll()
    end
  end
end

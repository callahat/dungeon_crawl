defmodule DungeonCrawl.TileTemplates.TileSeeder.Items do
  alias DungeonCrawl.TileTemplates

  def ammo do
    TileTemplates.update_or_create_tile_template!(
      "ammo",
      %{character: "ä",
        name: "Ammo",
        description: "A box of ammo",
        state: %{"pushable" => true},
        color: "olivedrab",
        public: true,
        active: true,
        group_name: "items",
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                #sound pickup_blip, ?sender
                You found some ammo
                #give ammo, 6, ?sender
                #die
                :shot
                :bombed
                #sound bomb
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
        state: %{"destroyable" => true, "pushable" => true},
        color: "green",
        background_color: "black",
        public: true,
        active: true,
        group_name: "items",
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                Dolla bills, make it rain
                #random cash, 5-10
                #give cash, @cash, ?sender
                #sound pickup_blip, ?sender
                #die
                """
    })
  end

  def fireball_wand do
    TileTemplates.update_or_create_tile_template!(
      "fireball_wand",
      %{character: "/",
        name: "Fireball Wand",
        description: "A wand you can use to shoot fireballs",
        state: %{"blocking" => false, "soft" => true, "pushable" => true, "blocking_light" => false},
        color: "brown",
        public: true,
        active: true,
        group_name: "items",
        script: """
        :main
        #end
        :touch
        #if ! ?sender@player, main
        You found a magic wand!
        #equip fireball_wand, ?sender
        #sound pickup_blip, ?sender
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
        state: %{"destroyable" => true, "blocking" => true, "soft" => true, "pushable" => true, "blocking_light" => false},
        color: "blue",
        public: true,
        active: true,
        group_name: "items",
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                You found a gem!
                #give gems, 1, ?sender
                #give score, 1, ?sender
                #sound pickup_blip, ?sender
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
        state: %{"pushable" => true},
        color: "red",
        public: true,
        active: true,
        group_name: "items",
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                Restored some health
                #sound heal, ?sender
                #give health, 10, ?sender, 100
                #die
                """
    })
  end

  def levitation_potion do
    TileTemplates.update_or_create_tile_template!(
      "levitation_potion",
      %{character: "!",
        name: "Levitation Potion",
        description: "It'll make you float",
        state: %{"blocking" => false, "soft" => true, "pushable" => true, "blocking_light" => false},
        color: "blue",
        public: true,
        active: true,
        group_name: "items",
        script: """
        :main
        #end
        :touch
        #if ! ?sender@player, main
        You found a magic potion of levitation!
        #equip levitation_potion, ?sender
        #sound pickup_blip, ?sender
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
        state: %{"pushable" => true},
        color: "red",
        background_color: "white",
        public: true,
        active: true,
        group_name: "items",
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                This will stop the bleeding
                #give health, 50, ?sender, 100
                #sound heal, ?sender
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
        state: %{"pushable" => true, "wait_cycles" => 2, "light_source" => true, "light_range" => 1},
        public: true,
        active: true,
        group_name: "items",
        animate_random: true,
        animate_period: 1,
        animate_colors: "red, orange, yellow,cyan, magenta, blue, white, green, purple, darkcyan, darkred",
        script: """
                :main
                #end
                :touch
                #if ! ?sender@player, main
                ** YOUR TEXT HERE **
                   yup right here
                #die
                """
    })
  end

  def stone do
    TileTemplates.update_or_create_tile_template!(
      "stone",
      %{character: "*",
        name: "Stone",
        description: "A small stone fits nicely in the palm of your hand",
        state: %{"blocking" => false, "soft" => true, "pushable" => true, "blocking_light" => false, "damage" => 5, "not_pushing" => true, "wait_cycles" => 2},
        color: "gray",
        public: true,
        active: true,
        group_name: "items",
        script: """
        #if @thrown, thrown
        :main
        #end
        :touch
        #if ! ?sender@player, main
        Picked up a stone
        #equip stone, ?sender
        #sound pickup_blip, ?sender
        #die
        :thrown
        #zap touch
        @flying = true
        #walk @facing
        :thud
        :touch
        @flying=false
        #restore thrown
        #restore touch
        #send shot, ?sender
        #send main
        """
      })
  end

  def torch do
    TileTemplates.update_or_create_tile_template!(
      "torch",
      %{character: "¥",
        name: "Torch",
        description: "A torch",
        state: %{},
        color: "brown",
        public: true,
        active: true,
        group_name: "items",
        script: """
        :main
        #end
        :touch
        #if ! ?sender@player, main
        A torch to light the way
        #give torches, 1, ?sender
        #sound pickup_blip, ?sender
        #die
        """
      })
  end

  defmacro __using__(_params) do
    quote do
      def ammo(), do: unquote(__MODULE__).ammo()
      def cash(), do: unquote(__MODULE__).cash()
      def fireball_wand(), do: unquote(__MODULE__).fireball_wand()
      def gem(), do: unquote(__MODULE__).gem()
      def heart(), do: unquote(__MODULE__).heart()
      def levitation_potion(), do: unquote(__MODULE__).levitation_potion()
      def medkit(), do: unquote(__MODULE__).medkit()
      def scroll(), do: unquote(__MODULE__).scroll()
      def stone(), do: unquote(__MODULE__).stone()
      def torch(), do: unquote(__MODULE__).torch()
    end
  end
end

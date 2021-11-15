defmodule DungeonCrawl.Equipment.Seeder.Item do
  alias DungeonCrawl.Equipment

  def fireball_wand do
    Equipment.update_or_create_item!(
      "fireball_wand",
      %{name: "Fireball Wand",
        description: "It shoots exploding fireballs",
        public: true,
        weapon: true,
        script: """
        #put direction: here, slug: fireball, facing: @facing
        #if ?random@10 != 10, 1
        #end
        The wand broke!
        #die
        """
      })
  end

  def gun do
    Equipment.update_or_create_item!(
      "gun",
      %{name: "Gun",
        description: "It shoots bullets",
        public: true,
        weapon: true,
        script: """
        #take ammo, 1, ?self, error
        #shoot @facing
        #end
        :error
        Out of ammo!
        """
      })
  end

  def levitation_potion do
    Equipment.update_or_create_item!(
      "levitation_potion",
      %{name: "Levitation Potion",
        description: "You feel light",
        public: true,
        weapon: false,
        consumable: true,
        script: """
        @flying = true
        """
      })
  end

  def stone do
    Equipment.update_or_create_item!(
      "stone",
      %{name: "Stone",
        description: "A small chunk of the planets crust, easily tossed.",
        public: true,
        weapon: true,
        consumable: true,
        script: """
        #put direction: here, slug: stone, facing: @facing, thrown: true
        """
      })
  end

  defmacro __using__(_params) do
    quote do
      def fireball_wand(), do: unquote(__MODULE__).fireball_wand()
      def gun(), do: unquote(__MODULE__).gun()
      def levitation_potion(), do: unquote(__MODULE__).levitation_potion()
      def stone(), do: unquote(__MODULE__).stone()
    end
  end
end

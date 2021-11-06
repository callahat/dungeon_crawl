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
        #put direction: @facing, slug: fireball, facing: @facing
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

  defmacro __using__(_params) do
    quote do
      def fireball_wand(), do: unquote(__MODULE__).fireball_wand()
      def gun(), do: unquote(__MODULE__).gun()
    end
  end
end

defmodule DungeonCrawl.Equipment.Seeder.Item do
  alias DungeonCrawl.Equipment

  def gun do
    Equipment.update_or_create_item!(
      "gun",
      %{name: "Gun",
        description: "It shoots bullets",
        public: true,
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
      def gun(), do: unquote(__MODULE__).gun()
    end
  end
end

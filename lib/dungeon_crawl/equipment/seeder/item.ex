defmodule DungeonCrawl.Equipment.Seeder.Item do
  alias DungeonCrawl.Equipment

  def gun do
    Equipment.update_or_create_item!(
      "gun",
      %{name: "Gun",
        description: "It shoots bullets",
        public: true,
        script: """
        #if @ammo <= 0, error
        @ammo -= 1
        #shoot @facing
        #end
        :error
        Out of ammo!
        """
      })
  end
end

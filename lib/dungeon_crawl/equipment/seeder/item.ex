defmodule DungeonCrawl.Equipment.Seeder do
  alias DungeonCrawl.Repo
  alias DungeonCrawl.Equipment

  def ammo do
    Equipment.update_or_create_item!(
      "gun",
      %{name: "gun",
        description: "A box of ammo",
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

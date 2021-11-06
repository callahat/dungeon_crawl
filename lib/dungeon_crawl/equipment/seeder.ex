defmodule DungeonCrawl.Equipment.Seeder do
  use DungeonCrawl.Equipment.Seeder.Item

  def seed_all do
    fireball_wand()
    gun()

    :ok
  end
end

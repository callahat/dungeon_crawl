defmodule DungeonCrawl.Equipment.Seeder do
  use DungeonCrawl.Equipment.Seeder.Item

  def seed_all do
    gun()

    :ok
  end
end
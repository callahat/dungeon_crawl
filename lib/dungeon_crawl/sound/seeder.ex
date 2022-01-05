defmodule DungeonCrawl.Sound.Seeder do
  use DungeonCrawl.Sound.Seeder.Effect

  def seed_all do
    alarm()
    bomb()
    click()
    computing()
    rumble()
    shoot()

    :ok
  end
end

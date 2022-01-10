defmodule DungeonCrawl.Sound.Seeder do
  use DungeonCrawl.Sound.Seeder.Effect

  def seed_all do
    alarm()
    bomb()
    click()
    computing()
    door()
    fuzz_pop()
    harp_down()
    harp_up()
    heal()
    ouch()
    open_locked_door()
    pickup_blip()
    rumble()
    shoot()
    slide_down()
    slide_up()
    star_fire()
    trudge()

    :ok
  end
end

defmodule DungeonCrawl.Sound.SeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Sound.Seeder
  alias DungeonCrawl.Sound.Effect

  test "individually seeding items" do
    assert %Effect{name: "Alarm"} = Seeder.alarm()
    assert Repo.one(from i in Effect, where: i.name == "Alarm")

    assert %Effect{name: "Bomb"} = Seeder.bomb()
    assert Repo.one(from i in Effect, where: i.name == "Bomb")

    assert %Effect{name: "Click"} = Seeder.click()
    assert Repo.one(from i in Effect, where: i.name == "Click")

    assert %Effect{name: "Computing"} = Seeder.computing()
    assert Repo.one(from i in Effect, where: i.name == "Computing")

    assert %Effect{name: "Rumble"} = Seeder.rumble()
    assert Repo.one(from i in Effect, where: i.name == "Rumble")

    assert %Effect{name: "Shoot"} = Seeder.shoot()
    assert Repo.one(from i in Effect, where: i.name == "Shoot")
  end

  test "seed_all/0" do
    initial_count = Repo.one(from i in Effect, select: count(i.id))
    Seeder.seed_all()
    seeded_count = Repo.one(from i in Effect, select: count(i.id))
    assert seeded_count - initial_count == 6

    # does not add the seeds again
    Seeder.seed_all()
    seeded_count2 = Repo.one(from i in Effect, select: count(i.id))
    assert seeded_count2 - initial_count == 6
  end
end

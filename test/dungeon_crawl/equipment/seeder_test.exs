defmodule DungeonCrawl.Equipment.SeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Equipment.Seeder
  alias DungeonCrawl.Equipment.Item

  test "individually seeding items" do
    assert %Item{name: "Gun"} = Seeder.gun()
    assert Repo.one(from i in Item, where: i.name == "Gun")

    assert %Item{name: "Fireball Wand"} = Seeder.fireball_wand()
    assert Repo.one(from i in Item, where: i.name == "Fireball Wand")

    assert %Item{name: "Levitation Potion"} = Seeder.levitation_potion()
    assert Repo.one(from i in Item, where: i.name == "Levitation Potion")

    assert %Item{name: "Stone"} = Seeder.stone()
    assert Repo.one(from i in Item, where: i.name == "Stone")
  end

  test "seed_all/0" do
    initial_count = Repo.one(from i in Item, select: count(i.id))
    Seeder.seed_all()
    seeded_count = Repo.one(from i in Item, select: count(i.id))
    assert seeded_count - initial_count == 4

    # does not add the seeds again
    Seeder.seed_all()
    seeded_count2 = Repo.one(from i in Item, select: count(i.id))
    assert seeded_count2 - initial_count == 4
  end
end

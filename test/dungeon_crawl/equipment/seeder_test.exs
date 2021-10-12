defmodule DungeonCrawl.Equipment.SeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Equipment.Seeder
  alias DungeonCrawl.Equipment.Item

  test "individually seeding items" do
    assert %Item{name: "Gun"} = Seeder.gun()
    assert Repo.one(from i in Item, where: i.name == "Gun")
  end

  test "seed_all/0" do
    initial_count = Repo.one(from i in Item, select: count(i.id))
    Seeder.seed_all()
    seeded_count = Repo.one(from i in Item, select: count(i.id))
    assert seeded_count - initial_count == 1

    # does not add the seeds again
    Seeder.seed_all()
    seeded_count2 = Repo.one(from i in Item, select: count(i.id))
    assert seeded_count2 - initial_count == 1
  end
end

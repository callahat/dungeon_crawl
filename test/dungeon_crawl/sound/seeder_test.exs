defmodule DungeonCrawl.Sound.SeederTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.Sound.Seeder
  alias DungeonCrawl.Sound.Effect

  test "individually seeding items" do
    [
      {"Alarm", :alarm},
      {"Bomb", :bomb},
      {"Click", :click},
      {"Computing", :computing},
      {"Door", :door},
      {"Fuzz Pop", :fuzz_pop},
      {"Harp Down", :harp_down},
      {"Harp Up", :harp_up},
      {"Heal", :heal},
      {"Ouch", :ouch},
      {"Open Locked Door", :open_locked_door},
      {"Pickup Blip", :pickup_blip},
      {"Slide Down", :slide_down},
      {"Slide Up", :slide_up},
      {"Rumble", :rumble},
      {"Secret Door", :secret_door},
      {"Shoot", :shoot},
      {"Star Fire", :star_fire},
      {"Trudge", :trudge},
    ]
    |> Enum.each(fn {name, method} ->
         assert %Effect{name: ^name} = apply(Seeder, method, [])
         assert Repo.one(from i in Effect, where: i.name == ^name)
       end)
  end

  test "seed_all/0" do
    initial_count = Repo.one(from i in Effect, select: count(i.id))
    Seeder.seed_all()
    seeded_count = Repo.one(from i in Effect, select: count(i.id))
    assert seeded_count - initial_count == 19

    # does not add the seeds again
    Seeder.seed_all()
    seeded_count2 = Repo.one(from i in Effect, select: count(i.id))
    assert seeded_count2 - initial_count == 19
  end
end

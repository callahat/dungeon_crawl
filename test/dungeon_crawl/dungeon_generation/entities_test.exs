defmodule DungeonCrawl.DungeonGeneration.EntitiesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.DungeonGeneration.Entities

  describe "randomize/2" do
    test "it returns a list of characters" do
      assert entities = Entities.randomize(3)
      assert length(entities) == 3
      assert entities = Entities.randomize(1)
      assert length(entities) == 1
      assert [] == Entities.randomize(0)
    end
  end

  describe "random_entity/0" do
    test "it returns a random entity character" do
      assert entity = Entities.random_entity
      assert is_integer(entity) # a character is just an integer in this case
    end
  end
end


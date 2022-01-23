defmodule DungeonCrawl.DungeonGeneration.Entities do
  @moduledoc """
  Entities are a more broadly defined class of tiles that can appear in a solo autogenerated dungeon.
  When an entity tile is placed in a generated dungeon, there should also be a "floor" tile placed
  beneath it, otherwise there will be a "hole" in the map should the entity move or die.
  Entities can include monsters as well as items.
  """

  @doc """
  Returns a list of random entity characters, first parameter is the number of entities to return.
  """
  def randomize(_quantity, entities \\ [])
  def randomize(0, entities), do: entities
  def randomize(quantity, entities) do
    randomize(quantity - 1, [random_entity() | entities])
  end

  @doc """
  Returns a random entity. Different entities have different chances of being returned.
  """
  def random_entity() do
    chance = :rand.uniform(100)
    # coveralls-ignore-start
    cond do
      chance > 99 -> ?r
      chance > 98 -> ?x
      chance > 96 -> ?Z
      chance > 85 -> ?♣
      chance > 80 -> ?ϴ
      chance > 70 -> ?ö
      chance > 40 -> ?Ω
      chance > 29 -> ?π
      # 4 % chance of an NPC
      chance > 27 -> ?☹
      chance > 25 -> ?☺
      # 25% chance its an item instead of a monster
      chance > 20 -> ?ä
      chance > 15 -> ?▪
      chance > 13 -> ?♂
      chance > 10 -> ?$
      chance >  7 -> ?♦
      chance >  3 -> ?♥
      true        -> ?✚
    end
    # coveralls-ignore-stop
  end

  @doc """
  Returns a list of treasure characters
  """
  def treasures() do
    'ä$♦♥'
  end
end


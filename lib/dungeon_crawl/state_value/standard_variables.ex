defmodule DungeonCrawl.StateValue.StandardVariables do
  @dungeon [
             "no_scoring",
             "starting_lives",
           ]
  @level   [
             "fog_range",
             "reset_player_when_damaged",
             "pacifism",
             "visibility",
           ]
  @tile    [
             "blocking",
             "damage",
             "destroyable",
             "health",
             "not_pushing",
             "not_squishing",
             "points",
             "pullable",
             "pulling",
             "pushable",
             "squishable",
             "teleporter",
             "wait_cycles",
           ]





  @doc """
  Returns the standard variables for the dungeon.
  """
  def dungeon(), do: @dungeon

  @doc """
  Returns the standard variables for the level.
  """
  def level(), do: @level

  @doc """
  Returns the standard variables for the tile (and tile template).
  """
  def tile(), do: @tile
end


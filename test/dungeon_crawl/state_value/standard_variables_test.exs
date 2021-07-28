defmodule DungeonCrawl.StateValue.StandardVariablesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.StateValue.StandardVariables

  test "dungeon" do
    assert [
             "no_scoring",
             "starting_lives",
           ] == StandardVariables.dungeon
  end

  test "level" do
    assert [
             "fade_overlay",
             "fog_range",
             "reset_player_when_damaged",
             "pacifism",
             "visibility",
           ] == StandardVariables.level
  end

  test "tile" do
    assert [
             "blocking",
             "damage",
             "destroyable",
             "flying",
             "health",
             "low",
             "not_pushing",
             "not_squishing",
             "points",
             "pullable",
             "pulling",
             "pushable",
             "squishable",
             "teleporter",
             "wait_cycles",
           ] == StandardVariables.tile
  end
end

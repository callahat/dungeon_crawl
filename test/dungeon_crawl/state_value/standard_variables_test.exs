defmodule DungeonCrawl.StateValue.StandardVariablesTest do
  use DungeonCrawl.DataCase

  alias DungeonCrawl.StateValue.StandardVariables

  test "dungeon" do
    assert [
             "no_scoring",
             "saveable",
             "starting_equipment",
             "starting_lives",
           ] == StandardVariables.dungeon
  end

  test "level" do
    assert [
             "fade_overlay",
             "fog_range",
             "reset_player_when_damaged",
             "reset_when_no_players",
             "solo",
             "pacifism",
             "visibility",
           ] == StandardVariables.level
  end

  test "tile" do
    assert [
             "blocking",
             "blocking_light",
             "damage",
             "destroyable",
             "flying",
             "health",
             "light_range",
             "light_source",
             "low",
             "not_pushing",
             "not_squishing",
             "points",
             "pullable",
             "pulling",
             "pushable",
             "soft",
             "squishable",
             "teleporter",
             "wait_cycles",
           ] == StandardVariables.tile
  end
end

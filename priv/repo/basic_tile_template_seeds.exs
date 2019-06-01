# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     DungeonCrawl.Repo.insert!(%DungeonCrawl.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias DungeonCrawl.Repo
alias DungeonCrawl.TileTemplates.TileTemplate

# Basic tile templates

Repo.insert! %TileTemplate{character: ".", name: "Floor", description: "Just a dusty floor", color: "", background_color: "", responders: "{move: {:ok}}"}
Repo.insert! %TileTemplate{character: "#", name: "Wall",  description: "A Rough wall"}
Repo.insert! %TileTemplate{character: " ", name: "Rock",  description: "Impassible stone"}

open_door   = Repo.insert! %TileTemplate{character: "'", name: "Open Door", description: "An open door"}
closed_door = Repo.insert! %TileTemplate{character: "+", name: "Closed Door", description: "A closed door"}

Repo.update! TileTemplate.changeset(open_door, %{responders: "{move: {:ok}, close: {:ok, replace: [#{closed_door.id}]}}"})
Repo.update! TileTemplate.changeset(closed_door, %{responders: "{open: {:ok, replace: [#{open_door.id}]}}"})

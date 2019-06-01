# Script for populating the database. You can run it as:
#
#     mix run priv/repo/basic_tile_template_seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     DungeonCrawl.Repo.insert!(%DungeonCrawl.SomeModel{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query

alias DungeonCrawl.Repo
alias DungeonCrawl.TileTemplates.TileTemplate

# Basic tile templates

floor = case Repo.one(from t in TileTemplate, where: t.character == ".", limit: 1, order_by: :inserted_at) do
          nil -> Repo.insert! %TileTemplate{character: ".", name: "Floor", description: "Just a dusty floor", color: "", background_color: "", responders: "{move: {:ok}}"}
          t   -> t
        end
wall  = case Repo.one(from t in TileTemplate, where: t.character == "#", limit: 1, order_by: :inserted_at) do
          nil -> Repo.insert! %TileTemplate{character: "#", name: "Wall",  description: "A Rough wall"}
          t   -> t
        end
rock  = case Repo.one(from t in TileTemplate, where: t.character == " ", limit: 1, order_by: :inserted_at) do
          nil -> Repo.insert! %TileTemplate{character: " ", name: "Rock",  description: "Impassible stone"}
          t   -> t
        end

open_door    = case Repo.one(from t in TileTemplate, where: t.character == "'", limit: 1, order_by: :inserted_at) do
                 nil -> Repo.insert! %TileTemplate{character: "'", name: "Open Door", description: "An open door"}
                 t   -> t
               end
closed_door  = case Repo.one(from t in TileTemplate, where: t.character == "+", limit: 1, order_by: :inserted_at) do
                 nil -> Repo.insert! %TileTemplate{character: "+", name: "Closed Door", description: "A closed door"}
                 t   -> t
               end

Repo.update! TileTemplate.changeset(open_door, %{responders: "{move: {:ok}, close: {:ok, replace: [#{closed_door.id}]}}"})
Repo.update! TileTemplate.changeset(closed_door, %{responders: "{open: {:ok, replace: [#{open_door.id}]}}"})

template_map = %{"." => floor, "#" => wall, " " => rock, "'" => open_door, "+" => closed_door}

# Link all the map tiles that aren't already linked

alias DungeonCrawl.Dungeon.MapTile

Repo.all(MapTile)
|> Enum.reduce(%{},fn(mt,acc) -> if template_map[mt.tile] do
                        Repo.update! MapTile.changeset(mt, %{tile_template_id: template_map[mt.tile].id})
                        Map.put(acc, mt.tile, if(acc[mt.tile], do: acc[mt.tile]+1, else: 1))
                      else
                        Map.put(acc, mt.tile, if(acc[mt.tile], do: acc[mt.tile]+1, else: 1))
                      end
            end)
|> inspect
|> IO.puts

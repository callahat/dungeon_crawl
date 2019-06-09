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

alias DungeonCrawl.Repo
alias DungeonCrawl.Dungeon.MapTile

# Basic tile templates
template_map = DungeonCrawl.TileTemplates.TileSeeder.basic_tiles

# Link all the map tiles that aren't already linked
counts = Repo.all(MapTile)
|> Enum.reduce(%{},fn(mt,acc) -> if template_map[mt.tile] do
                        Repo.update! MapTile.changeset(mt, %{tile_template_id: template_map[mt.tile].id})
                        Map.put(acc, mt.tile, if(acc[mt.tile], do: acc[mt.tile]+1, else: 1))
                      else
                        Map.put(acc, mt.tile, if(acc[mt.tile], do: acc[mt.tile]+1, else: 1))
                      end
            end)
counts
|> inspect
|> IO.puts

IO.puts "Characters that didn't exist in the template map (if any, add them and rereun seeds)"
IO.puts inspect Map.keys(counts) -- Map.keys(template_map)

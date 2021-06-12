# Script for populating the database. You can run it as:
#
#     mix run priv/repo/basic_tile_template_seeds.exs

IO.puts "Adding or updating the standard tiles"

DungeonCrawl.TileTemplates.TileSeeder.seed_all

IO.puts "Added or updated the standard tiles"

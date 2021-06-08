defmodule DungeonCrawl.Repo.Migrations.RenameMapSetsToDungeons do
  use Ecto.Migration

  def change do
    # Rename the tables
    rename table("dungeon_map_tiles"), to: table("tiles")
    rename table("dungeons"), to: table("levels")
    rename table("map_sets"), to: table("dungeons")

    rename table("map_tile_instances"), to: table("tile_instances")
    rename table("map_instances"), to: table("level_instances")
    rename table("map_set_instances"), to: table("dungeon_instances")

    # Rename the foreign key columns
    rename table("tiles"), :dungeon_id, to: :level_id
    rename table("levels"), :map_set_id, to: :dungeon_id
    # rename table("dungeons") # nothing to update?

    rename table("tile_instances"), :map_instance_id, to: :level_instance_id
    rename table("level_instances"), :map_id, to: :level_id
    rename table("level_instances"), :map_set_instance_id, to: :dungeon_instance_id
    rename table("dungeon_instances"), :map_set_id, to: :dungeon_id

    # foreign keys for other relations
    rename table("spawn_locations"), :dungeon_id, to: :level_id
    rename table("scores"), :map_set_id, to: :dungeon_id
    rename table("player_locations"), :map_tile_instance_id, to: :tile_instance_id
  end
end

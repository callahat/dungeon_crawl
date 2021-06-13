defmodule DungeonCrawl.Repo.Migrations.UpdateDbConstraintAndSequenceNames do
  use Ecto.Migration

  def up do
# update sequence names
    [ {"dungeon_map_tiles_id_seq",  "tiles_id_seq"},
      {"dungeons_id_seq",           "levels_id_seq"},
      {"map_sets_id_seq",           "dungeons_id_seq"},
      {"map_tile_instances_id_seq", "tile_instances_id_seq"},
      {"map_instances_id_seq",      "level_instances_id_seq"},
      {"map_set_instances_id_seq",  "dungeon_instances_id_seq"},
    ]
    |> Enum.each(fn {old_seq, new_seq} ->
         execute "ALTER SEQUENCE #{old_seq} RENAME TO #{new_seq};"
       end)

#update the index names
    [ {"dungeon_map_tiles_dungeon_id_row_col_index",     "tiles_level_id_row_col_index"},
      {"dungeon_map_tiles_tile_template_id_index",       "tiles_tile_template_id_index"},
      {"dungeons_map_set_id_index",                      "levels_dungeon_id_index"},
      {"dungeons_map_set_id_number_index",               "levels_dungeon_id_number_index"},
      {"map_instances_map_id_index",                     "level_instances_level_id_index"},
      {"map_instances_map_set_instance_id_index",        "level_instances_dungeon_instance_id_index"},
      {"map_instances_map_set_instance_id_number_index", "level_instances_dungeon_instance_id_number_index"},
      {"map_sets_active_index",                          "dungeons_active_index"},
      {"map_sets_deleted_at_index",                      "dungeons_deleted_at_index"},
      {"map_sets_line_identifier_index",                 "dungeons_line_identifier_index"},
      {"map_tile_instances_map_instance_id_index",       "tile_instances_level_instance_id_index"},
      {"player_locations_map_tile_instance_id_index",    "player_locations_tile_instance_id_index"},
      {"scores_map_set_id_index",                        "scores_dungeon_id_index"},
      {"spawn_locations_dungeon_id_index",               "spawn_locations_level_id_index"},
      {"spawn_locations_dungeon_id_row_col_index",       "spawn_locations_level_id_row_col_index"}
    ]
    |> Enum.each(fn {old_name, new_name} ->
         execute "ALTER INDEX #{old_name} RENAME TO #{new_name};"
       end)

# rename constraints
    [
      # primary keys
      {"tiles",             "dungeon_map_tiles_pkey",  "tiles_pkey"},
      {"levels",            "dungeons_pkey",           "levels_pkey"},
      {"dungeons",          "map_sets_pkey",           "dungeons_pkey"},
      {"tile_instances",    "map_tile_instances_pkey", "tile_instances_pkey"},
      {"level_instances",   "map_instances_pkey",      "level_instances_pkey"},
      {"dungeon_instances", "map_set_instances_pkey",  "dungeon_instances_pkey"},
      # foreign keys
      {"tiles",             "dungeon_map_tiles_dungeon_id_fkey", "tiles_level_id_fkey"},
      {"tiles",             "dungeon_map_tiles_tile_template_id_fkey", "tiles_tile_template_id_fkey"},
      {"levels",            "dungeons_map_set_id_fkey", "levels_dungeon_id_fkey"},
      {"level_instances",   "map_instances_map_id_fkey", "level_instances_level_id_fkey"},
      {"level_instances",   "map_instances_map_set_instance_id_fkey", "level_instances_dungeon_instance_id_fkey"},
      {"dungeon_instances", "map_set_instances_map_set_id_fkey", "dungeon_instances_dungeon_id_fkey"},
      {"dungeons",          "map_sets_previous_version_id_fkey", "dungeons_previous_version_id_fkey"},
      {"dungeons",          "map_sets_user_id_fkey", "dungeons_user_id_fkey"},
      {"tile_instances",    "map_tile_instances_map_instance_id_fkey", "tile_instances_level_instance_id_fkey"},
      {"player_locations",  "player_locations_map_tile_id_fkey", "player_locations_tile_id_fkey"},
      {"player_locations",  "player_locations_map_tile_instance_id_fkey", "player_locations_tile_instance_id_fkey"},
      {"scores",            "scores_map_set_id_fkey", "scores_dungeon_id_fkey"},
      {"spawn_locations",   "spawn_locations_dungeon_id_fkey", "spawn_locations_level_id_fkey"},
    ]
    |> Enum.each(fn {table, old_name, new_name} ->
         execute "ALTER TABLE #{table} RENAME CONSTRAINT \"#{old_name}\" TO \"#{new_name}\";"
       end)
  end

  def down do
# update sequence names
    [ {"dungeon_map_tiles_id_seq",  "tiles_id_seq"},
      {"dungeons_id_seq",           "levels_id_seq"},
      {"map_sets_id_seq",           "dungeons_id_seq"},
      {"map_tile_instances_id_seq", "tile_instances_id_seq"},
      {"map_instances_id_seq",      "level_instances_id_seq"},
      {"map_set_instances_id_seq",  "dungeon_instances_id_seq"},
    ]
    |> Enum.reverse()
    |> Enum.each(fn {old_seq, new_seq} ->
         execute "ALTER SEQUENCE #{new_seq} RENAME TO #{old_seq};"
       end)

#update the index names
    [ {"dungeon_map_tiles_dungeon_id_row_col_index",     "tiles_level_id_row_col_index"},
      {"dungeon_map_tiles_tile_template_id_index",       "tiles_tile_template_id_index"},
      {"dungeons_map_set_id_index",                      "levels_dungeon_id_index"},
      {"dungeons_map_set_id_number_index",               "levels_dungeon_id_number_index"},
      {"map_instances_map_id_index",                     "level_instances_level_id_index"},
      {"map_instances_map_set_instance_id_index",        "level_instances_dungeon_instance_id_index"},
      {"map_instances_map_set_instance_id_number_index", "level_instances_dungeon_instance_id_number_index"},
      {"map_sets_active_index",                          "dungeons_active_index"},
      {"map_sets_deleted_at_index",                      "dungeons_deleted_at_index"},
      {"map_sets_line_identifier_index",                 "dungeons_line_identifier_index"},
      {"map_tile_instances_map_instance_id_index",       "tile_instances_level_instance_id_index"},
      {"player_locations_map_tile_instance_id_index",    "player_locations_tile_instance_id_index"},
      {"scores_map_set_id_index",                        "scores_dungeon_id_index"},
      {"spawn_locations_dungeon_id_index",               "spawn_locations_level_id_index"},
      {"spawn_locations_dungeon_id_row_col_index",       "spawn_locations_level_id_row_col_index"}
    ]
    |> Enum.reverse()
    |> Enum.each(fn {old_name, new_name} ->
         execute "ALTER INDEX #{new_name} RENAME TO #{old_name};"
       end)

# rename constraints
    [
      # primary keys
      {"tiles",             "dungeon_map_tiles_pkey",  "tiles_pkey"},
      {"levels",            "dungeons_pkey",           "levels_pkey"},
      {"dungeons",          "map_sets_pkey",           "dungeons_pkey"},
      {"tile_instances",    "map_tile_instances_pkey", "tile_instances_pkey"},
      {"level_instances",   "map_instances_pkey",      "level_instances_pkey"},
      {"dungeon_instances", "map_set_instances_pkey",  "dungeon_instances_pkey"},
      # foreign keys
      {"tiles",             "dungeon_map_tiles_dungeon_id_fkey", "tiles_level_id_fkey"},
      {"tiles",             "dungeon_map_tiles_tile_template_id_fkey", "tiles_tile_template_id_fkey"},
      {"levels",            "dungeons_map_set_id_fkey", "levels_dungeon_id_fkey"},
      {"level_instances",   "map_instances_map_id_fkey", "level_instances_level_id_fkey"},
      {"level_instances",   "map_instances_map_set_instance_id_fkey", "level_instances_dungeon_instance_id_fkey"},
      {"dungeon_instances", "map_set_instances_map_set_id_fkey", "dungeon_instances_dungeon_id_fkey"},
      {"dungeons",          "map_sets_previous_version_id_fkey", "dungeons_previous_version_id_fkey"},
      {"dungeons",          "map_sets_user_id_fkey", "dungeons_user_id_fkey"},
      {"tile_instances",    "map_tile_instances_map_instance_id_fkey", "tile_instances_level_instance_id_fkey"},
      {"player_locations",  "player_locations_map_tile_id_fkey", "player_locations_tile_id_fkey"},
      {"player_locations",  "player_locations_map_tile_instance_id_fkey", "player_locations_tile_instance_id_fkey"},
      {"scores",            "scores_map_set_id_fkey", "scores_dungeon_id_fkey"},
      {"spawn_locations",   "spawn_locations_dungeon_id_fkey", "spawn_locations_level_id_fkey"},
    ]
    |> Enum.reverse()
    |> Enum.each(fn {table, old_name, new_name} ->
         execute "ALTER TABLE #{table} RENAME CONSTRAINT \"#{new_name}\" TO \"#{old_name}\";"
       end)
  end
end

defmodule DungeonCrawl.Repo.Migrations.CopyDataForDungeonInstances do
  use Ecto.Migration

  def up do
    _copy_dungeons_with_a_player_to_instance()
    _update_map_instance_sequence()
    _copy_map_tiles_to_instance_for_map_instance()
    _update_map_tile_instance_sequence()
    _update_player_locations()
  end

  defp _copy_dungeons_with_a_player_to_instance() do
    execute """
      INSERT INTO map_instances(id, map_id, name, height, width, inserted_at, updated_at)
             SELECT g0.id, g0.id, g0.name, g0.height, g0.width, g0.inserted_at, g0.updated_at 
             FROM (SELECT d0."id", d0."name", d0."width", d0."height", d0."inserted_at", d0."updated_at", count(p2."id")
                   FROM "dungeons" AS d0
                   LEFT OUTER JOIN "dungeon_map_tiles" AS d1 ON d1."dungeon_id" = d0."id"
                   LEFT OUTER JOIN "player_locations" AS p2 ON p2."map_tile_id" = d1."id"
                   GROUP BY d0."id") AS g0
             WHERE g0.count > 0
    """
  end

  defp _update_map_instance_sequence() do
    execute """
      SELECT setval('map_instances_id_seq'::regclass, max(map_instances.id)) FROM map_instances
    """
  end

  defp _copy_map_tiles_to_instance_for_map_instance() do
    execute """
      INSERT INTO map_tile_instances(map_instance_id, id, row, col, z_index, tile_template_id)
      SELECT mi0.id, dmt0.id, dmt0.row, dmt0.col, dmt0.z_index, dmt0.tile_template_id
      FROM "map_instances" AS mi0
      LEFT OUTER JOIN "dungeon_map_tiles" AS dmt0 ON dmt0."dungeon_id" = mi0."map_id"
    """
  end

  defp _update_map_tile_instance_sequence() do
    execute """
      SELECT setval('map_tile_instances_id_seq'::regclass, max(map_tile_instances.id)) FROM map_tile_instances
    """
  end

  defp _update_player_locations() do
    execute """
      UPDATE player_locations
      set map_tile_instance_id = map_tile_id
      WHERE map_tile_instance_id IS NULL
    """
  end

  def down do
    _revert_player_locations()
    _reset_instance_tables()
  end

  defp _revert_player_locations() do
    execute """
      UPDATE player_locations
      set map_tile_id = map_tile_instance_id
      WHERE map_tile_id IS NULL
    """
    execute """
      UPDATE player_locations
      set map_tile_instance_id = NULL
    """
  end

  defp _reset_instance_tables() do
    execute "DELETE FROM map_tile_instances"
    execute "ALTER SEQUENCE map_tile_instances_id_seq RESTART WITH 1"
    execute "DELETE FROM map_instances"
    execute "ALTER SEQUENCE map_instances_id_seq RESTART WITH 1"
  end
end

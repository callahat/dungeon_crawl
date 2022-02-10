defmodule DungeonCrawl.Repo.Migrations.UpdateLevelInstanceNumberConstraint do
  use Ecto.Migration

  # using execute since the drop index seems to have a bug where it is not finding the named index to drop
  def up do
    execute "DROP INDEX level_instances_dungeon_instance_id_number_index;"
    execute "CREATE UNIQUE INDEX level_headers_dungeon_number_index ON public.level_headers USING btree (dungeon_instance_id, number);"
    execute """
            CREATE UNIQUE INDEX level_instances_dungeon_number_owned_by_player_index
            ON public.level_instances USING btree (dungeon_instance_id, number, player_location_id)
            WHERE player_location_id IS NOT NULL;
            """
    execute """
            CREATE UNIQUE INDEX level_instances_dungeon_number_shared_by_all_players_index
            ON public.level_instances USING btree (dungeon_instance_id, number)
            WHERE player_location_id IS NULL;
            """
  end

  def down do
    execute "DROP INDEX level_instances_dungeon_number_owned_by_player_index;"
    execute "DROP INDEX level_instances_dungeon_number_shared_by_all_players_index;"
    execute "DROP INDEX level_headers_dungeon_number_index;"
    execute "CREATE UNIQUE INDEX level_instances_dungeon_instance_id_number_index ON public.level_instances USING btree (dungeon_instance_id, number);"
  end
end

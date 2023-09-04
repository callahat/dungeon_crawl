defmodule DungeonCrawl.Repo.Migrations.UpdateStateDefaultValuesAndRestrictBeingNil do
  use Ecto.Migration

  @tables_with_state [
    :dungeons,
    :dungeon_instances,
    :levels,
    :level_instances,
    :tiles,
    :tile_instances,
    :tile_shortlists,
    :tile_templates
  ]

  def up do
    @tables_with_state
    |> Enum.each(fn table ->
      execute """
      UPDATE #{ table }
      set state = ''
      WHERE state IS NULL
      """
    end)

    @tables_with_state
    |> Enum.each(fn table ->
      alter table(table) do
        modify :state, :string, null: false, default: "", size: 2048
      end
    end)
  end

  def down do
    @tables_with_state
    |> Enum.each(fn table ->
      execute """
      ALTER TABLE #{ table }
      ALTER COLUMN state DROP DEFAULT,
      ALTER COLUMN state DROP NOT NULL,
      ALTER COLUMN state TYPE varchar(2048)
      """
    end)
  end
end

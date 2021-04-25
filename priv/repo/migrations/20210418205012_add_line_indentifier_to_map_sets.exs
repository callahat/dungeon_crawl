defmodule DungeonCrawl.Repo.Migrations.AddLineIndentifierToMapSets do
  use Ecto.Migration

  def up do
    alter table(:map_sets) do
      add :line_identifier, :integer
    end

    create index(:map_sets, [:line_identifier])

    flush()

    # run this to find ones that didnt' update correctly
    # Ecto.Adapters.SQL.query Repo, "select * from map_sets where line_identifier is null"
    if System.get_env("MIGRATE_MAP_SET_DATA_APRIL_2021") == "true" do
      _initial_line_identifiers()
      _update_line_identifiers()
    end
  end

  def down, do: nil

  defp _initial_line_identifiers() do
    execute """
      UPDATE map_sets
      SET line_identifier = id
      WHERE previous_version_id IS NULL
    """
  end

  defp _update_line_identifiers() do
    {:ok, %{rows: [blank_count]}} =
      Ecto.Adapters.SQL.query(DungeonCrawl.Repo, "select count(*) from map_sets where previous_version_id is null")
    _update_line_identifiers(blank_count)
  end

  defp _update_line_identifiers(last_blank_count) do
    execute """
      UPDATE map_sets as ms
      SET line_identifier = prev_ms.line_identifier
      FROM map_sets AS prev_ms
      WHERE prev_ms.id = ms.previous_version_id and
            ms.line_identifier IS NULL and
            prev_ms.line_identifier IS NOT NULL
    """

    {:ok, %{rows: [blank_count]}} =
      Ecto.Adapters.SQL.query(DungeonCrawl.Repo, "select count(*) from map_sets where previous_version_id is null")

    unless blank_count == 0 || blank_count == last_blank_count do
      _update_line_identifiers(blank_count)
    end
  end

  def down do
    alter table(:map_sets) do
      remove :line_identifier
    end
  end
end

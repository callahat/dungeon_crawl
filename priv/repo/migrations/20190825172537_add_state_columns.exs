defmodule DungeonCrawl.Repo.Migrations.AddStateColumns do
  use Ecto.Migration

  def up do
    alter table(:dungeon_map_tiles) do
      add :state, :string
    end
    alter table(:map_tile_instances) do
      add :state, :string
    end
    alter table(:tile_templates) do
      add :state, :string
    end

    flush()

    execute "UPDATE tile_templates " <>
            " SET state = 'blocking: true, open: false' " <>
            "WHERE responders LIKE '%open: {:ok%'"
    execute "UPDATE tile_templates " <>
            " SET state = 'blocking: false, open: true' " <>
            "WHERE responders LIKE '%open: {:ok%' and state IS NULL"
    execute "UPDATE tile_templates " <>
            " SET state = 'blocking: false' " <>
            "WHERE responders LIKE '%move: {:ok%' and state IS NULL"
    execute "UPDATE tile_templates " <>
            " SET state = 'blocking: true' " <>
            "WHERE state IS NULL"

    ["dungeon_map_tiles", "map_tile_instances"]
    |> Enum.each(fn(table) ->
         execute "UPDATE #{table} " <>
                 "  SET state = tt.state " <>
                 "FROM tile_templates tt " <>
                 "WHERE tile_template_id = tt.id"
       end)
  end

  def down do
    alter table(:dungeon_map_tiles) do
      remove :state
    end
    alter table(:map_tile_instances) do
      remove :state
    end
    alter table(:tile_templates) do
      remove :state
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.CreateLevelHeaders do
  use Ecto.Migration

  def change do
    create table(:level_headers) do
      add :number, :integer
      add :type, :integer
      add :level_id, references(:levels, on_delete: :delete_all)
      add :dungeon_instance_id, references(:dungeon_instances, on_delete: :delete_all)

      timestamps()
    end

    create index(:level_headers, [:level_id])
    create index(:level_headers, [:dungeon_instance_id])
  end
end

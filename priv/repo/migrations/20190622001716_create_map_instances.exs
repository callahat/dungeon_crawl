defmodule DungeonCrawl.Repo.Migrations.CreateMapInstances do
  use Ecto.Migration

  def change do
    create table(:map_instances) do
      add :name, :string
      add :width, :integer
      add :height, :integer
      add :map_id, references(:dungeons, on_delete: :delete_all)

      timestamps()
    end

    create index(:map_instances, [:map_id])
  end
end

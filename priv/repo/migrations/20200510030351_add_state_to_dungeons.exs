defmodule DungeonCrawl.Repo.Migrations.AddStateToDungeons do
  use Ecto.Migration

  def change do
    alter table(:dungeons) do
      add :state, :string
    end
    alter table(:map_instances) do
      add :state, :string
    end
  end
end

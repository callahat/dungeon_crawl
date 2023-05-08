defmodule DungeonCrawl.Repo.Migrations.AddProgramContextsToLevelInstances do
  use Ecto.Migration

  def change do
    alter table(:level_instances) do
      add :program_contexts, :jsonb
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.AddPassageExitsToLevelInstances do
  use Ecto.Migration

  def change do
    alter table(:level_instances) do
      add :passage_exits, :string
    end
  end
end

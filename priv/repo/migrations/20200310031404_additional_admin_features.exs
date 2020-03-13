defmodule DungeonCrawl.Repo.Migrations.AdditionalAdminFeatures do
  use Ecto.Migration

  def change do
    alter table(:dungeons) do
      add :max_instances, :integer
    end
  end
end

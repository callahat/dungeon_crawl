defmodule DungeonCrawl.Repo.Migrations.AddInstanceSharingColumns do
  use Ecto.Migration

  def change do
    alter table(:map_set_instances) do
      add :passcode, :string, size: 8
      add :is_private, :boolean
    end
  end
end

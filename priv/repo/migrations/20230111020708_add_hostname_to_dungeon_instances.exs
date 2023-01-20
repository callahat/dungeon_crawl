defmodule DungeonCrawl.Repo.Migrations.AddHostnameToDungeonInstances do
  use Ecto.Migration

  def change do
    alter table(:dungeon_instances) do
      add :host_name, :string
    end
  end
end

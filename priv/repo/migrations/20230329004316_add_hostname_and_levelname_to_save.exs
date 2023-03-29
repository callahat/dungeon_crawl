defmodule DungeonCrawl.Repo.Migrations.AddHostnameAndLevelnameToSave do
  use Ecto.Migration

  def change do
    alter table(:saved_games) do
      add :host_name, :string
      add :level_name, :string
    end
  end
end

defmodule DungeonCrawl.Repo.Migrations.AlterSavedGamesDeleteCascade do
  use Ecto.Migration

  def change do
    alter table(:saved_games) do
      modify :level_instance_id, references(:level_instances, on_delete: :delete_all),
             from: references(:level_instances, on_delete: :restrict)
    end
  end
end

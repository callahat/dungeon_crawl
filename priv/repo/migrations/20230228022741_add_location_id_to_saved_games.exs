defmodule DungeonCrawl.Repo.Migrations.AddLocationIdToSavedGames do
  use Ecto.Migration

  def change do
    alter table(:saved_games) do
      add :location_id, references(:player_locations, on_delete: :restrict)
    end

    create index(:saved_games, [:location_id])
  end
end

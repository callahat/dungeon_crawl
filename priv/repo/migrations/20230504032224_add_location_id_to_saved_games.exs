defmodule DungeonCrawl.Repo.Migrations.AddLocationIdToSavedGames do
  use Ecto.Migration

  def change do
    alter table(:saved_games) do
      add :player_location_id, references(:player_locations, on_delete: :delete_all)
    end

    create index(:saved_games, [:player_location_id])
  end
end

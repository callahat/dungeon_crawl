defmodule DungeonCrawl.Repo.Migrations.AddDeathCountToScores do
  use Ecto.Migration

  def change do
    alter table(:scores) do
      add :deaths, :integer
    end
  end
end

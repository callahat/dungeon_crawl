defmodule DungeonCrawl.Repo.Migrations.ChangeScoresDurationFromTimestampToInteger do
  use Ecto.Migration

  def change do
    alter table(:scores) do
      remove :duration
      add :duration, :integer
    end
  end
end

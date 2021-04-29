defmodule DungeonCrawl.Repo.Migrations.ChangeScoresDurationFromTimestampToInteger do
  use Ecto.Migration

  def up do
    alter table(:scores) do
      remove :duration
      add :duration, :integer
    end
  end

  def down do
    alter table(:scores) do
      remove :duration
      add :duration, :time
    end
  end
end

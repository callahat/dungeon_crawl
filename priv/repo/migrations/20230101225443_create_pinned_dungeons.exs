defmodule DungeonCrawl.Repo.Migrations.CreatePinnedDungeons do
  use Ecto.Migration

  def change do
    create table(:pinned_dungeons) do
      add :line_identifier, :integer

      timestamps()
    end
    create index(:pinned_dungeons, [:line_identifier], unique: true)
  end
end

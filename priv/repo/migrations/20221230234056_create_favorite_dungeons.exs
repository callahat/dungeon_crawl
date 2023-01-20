defmodule DungeonCrawl.Repo.Migrations.CreateFavoriteDungeons do
  use Ecto.Migration

  def change do
    create table(:favorite_dungeons) do
      add :user_id_hash, :string
      add :line_identifier, :integer

      timestamps()
    end
    create index(:favorite_dungeons, [:user_id_hash, :line_identifier], unique: true)

  end
end

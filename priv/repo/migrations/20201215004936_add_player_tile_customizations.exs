defmodule DungeonCrawl.Repo.Migrations.AddPlayerTileCustomizations do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :color, :string
      add :background_color, :string
    end
  end
end

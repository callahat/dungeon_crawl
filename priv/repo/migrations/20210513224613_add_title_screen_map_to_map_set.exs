defmodule DungeonCrawl.Repo.Migrations.AddTitleScreenMapToMapSet do
  use Ecto.Migration

  def change do
    alter table(:map_sets) do
      add :title_number, :integer
    end
  end
end

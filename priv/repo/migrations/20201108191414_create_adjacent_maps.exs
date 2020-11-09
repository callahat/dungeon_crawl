defmodule DungeonCrawl.Repo.Migrations.CreateAdjacentMaps do
  use Ecto.Migration

  def change do
    alter table(:dungeons) do
      add :number_north, :integer
      add :number_south, :integer
      add :number_east, :integer
      add :number_west, :integer
    end

    alter table(:map_instances) do
      add :number_north, :integer
      add :number_south, :integer
      add :number_east, :integer
      add :number_west, :integer
    end
  end
end

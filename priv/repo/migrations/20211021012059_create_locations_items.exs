defmodule DungeonCrawl.Repo.Migrations.CreateLocationsItems do
  use Ecto.Migration

  def change do
    create table(:locations_items) do
      add :location_id, references(:player_locations, on_delete: :delete_all)
      add :item_id, references(:items, on_delete: :delete_all)
    end

    create index(:locations_items, [:location_id, :item_id])
  end
end

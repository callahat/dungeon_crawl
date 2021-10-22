defmodule DungeonCrawl.Player.LocationsItems do
  use Ecto.Schema
  import Ecto.Changeset

  schema "locations_items" do
    belongs_to :location, DungeonCrawl.Player.Location
    belongs_to :item, DungeonCrawl.Equipment.Item
  end

  @doc false
  def changeset(location_item, attrs) do
    location_item
    |> cast(attrs, [:location_id, :item_id])
    |> validate_required([:location_id, :item_id])
  end
end

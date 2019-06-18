defmodule DungeonCrawl.Player.Location do
  use Ecto.Schema
  import Ecto.Changeset


  schema "player_locations" do
    field :user_id_hash, :string
    belongs_to :map_tile, DungeonCrawl.Dungeon.MapTile

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    if Map.has_key?(attrs, :row) or Map.has_key?(attrs, :col) or Map.has_key?(attrs, :dungeon_id) do
      IO.puts inspect attrs
    end

    location
    |> cast(attrs, [:user_id_hash, :map_tile_id])
    |> validate_required([:user_id_hash, :map_tile_id])
  end
end

defmodule DungeonCrawl.Player.Location do
  use Ecto.Schema
  import Ecto.Changeset


  schema "player_locations" do
    field :row, :integer
    field :col, :integer
    field :user_id_hash, :string
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
    belongs_to :map_tile, DungeonCrawl.Dungeon.MapTile
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:row, :col, :user_id_hash, :dungeon_id, :map_tile_id])
    |> validate_required([:row, :col, :user_id_hash, :dungeon_id, :map_tile_id])
  end
end

defmodule DungeonCrawl.Player.Location do
  use Ecto.Schema
  import Ecto.Changeset

  schema "player_locations" do
    field :user_id_hash, :string
    belongs_to :tile, DungeonCrawl.DungeonInstances.Tile, foreign_key: :tile_instance_id

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:user_id_hash, :tile_instance_id])
    |> validate_required([:user_id_hash, :tile_instance_id])
  end
end

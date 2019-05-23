defmodule DungeonCrawl.Player.Location do
  use Ecto.Schema
  import Ecto.Changeset


  schema "player_locations" do
    field :row, :integer
    field :col, :integer
    field :user_id_hash, :string
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map, foreign_key: :dungeon_id
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:row, :col, :user_id_hash, :dungeon_id])
    |> validate_required([:row, :col, :user_id_hash, :dungeon_id])
  end
end

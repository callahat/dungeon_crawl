defmodule DungeonCrawlWeb.PlayerLocation do
  use DungeonCrawl.Web, :model

  schema "player_locations" do
    field :row, :integer
    field :col, :integer
    field :user_id_hash, :string
    belongs_to :dungeon, DungeonCrawlWeb.Dungeon
    belongs_to :user, DungeonCrawlWeb.User

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:row, :col, :user_id_hash, :dungeon_id])
    |> validate_required([:row, :col, :user_id_hash, :dungeon_id])
  end
end

defmodule DungeonCrawl.DungeonMapTile do
  use DungeonCrawl.Web, :model

  schema "dungeon_map_tiles" do
    field :row, :integer
    field :col, :integer
    field :tile, :string
    belongs_to :dungeon, DungeonCrawl.Dungeon
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:row, :col, :tile])
    |> validate_length(:tile, min: 1, max: 1)
    |> validate_required([:row, :col])
  end
end

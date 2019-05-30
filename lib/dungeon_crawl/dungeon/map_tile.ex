defmodule DungeonCrawl.Dungeon.MapTile do
  use Ecto.Schema
  import Ecto.Changeset


  schema "dungeon_map_tiles" do
    field :row, :integer
    field :col, :integer
    field :tile, :string
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
  end

  @doc false
  def changeset(map_tile, attrs) do
    map_tile
    |> cast(attrs, [:row, :col, :tile])
    |> validate_length(:tile, min: 1, max: 1)
    |> validate_required([:row, :col])
  end
end

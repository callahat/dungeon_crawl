defmodule DungeonCrawl.Dungeon.MapTile do
  use Ecto.Schema
  import Ecto.Changeset


  schema "dungeon_map_tiles" do
    field :row, :integer
    field :col, :integer
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
  end

  @doc false
  def changeset(map_tile, attrs) do
    map_tile
    |> cast(attrs, [:row, :col, :tile_template_id])
    |> validate_required([:row, :col, :tile_template_id])
  end
end

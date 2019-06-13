defmodule DungeonCrawl.Dungeon.MapTile do
  use Ecto.Schema
  import Ecto.Changeset


  schema "dungeon_map_tiles" do
    field :row, :integer
    field :col, :integer
    field :z_index, :integer, default: 0
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
    has_many :player_locations, DungeonCrawl.Player.Location, on_delete: :delete_all
  end

  @doc false
  def changeset(map_tile, attrs) do
    map_tile
    |> cast(attrs, [:row, :col, :dungeon_id, :tile_template_id, :z_index])
    |> validate_required([:row, :col, :dungeon_id, :tile_template_id, :z_index])
  end
end

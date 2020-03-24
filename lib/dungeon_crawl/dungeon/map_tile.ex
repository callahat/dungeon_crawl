defmodule DungeonCrawl.Dungeon.MapTile do
  use Ecto.Schema
  import Ecto.Changeset

  # This is where the validations for color, background_color, and character live for now.
  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "dungeon_map_tiles" do
    field :row, :integer
    field :col, :integer
    field :z_index, :integer, default: 0

    field :name, :string

    field :background_color, :string
    field :character, :string
    field :color, :string

    field :state, :string
    field :script, :string, default: ""

    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
  end

  @doc false
  def changeset(map_tile, attrs) do
    map_tile
    |> cast(attrs, [:row, :col, :dungeon_id, :tile_template_id, :z_index, :character, :color, :background_color, :state, :script, :name])
    |> validate_required([:row, :col, :dungeon_id, :z_index])
    |> validate_length(:name, max: 32)
    |> TileTemplate.validate_renderables
  end
end

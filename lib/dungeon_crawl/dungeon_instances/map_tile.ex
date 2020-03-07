defmodule DungeonCrawl.DungeonInstances.MapTile do
  use Ecto.Schema
  import Ecto.Changeset

  # This is where the validations for color, background_color, and character live for now.
  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "map_tile_instances" do
    field :row, :integer
    field :col, :integer
    field :z_index, :integer, default: 0

    field :background_color, :string
    field :character, :string
    field :color, :string

    field :state, :string
    field :script, :string, default: ""

    belongs_to :dungeon, DungeonCrawl.DungeonInstances.Map, foreign_key: :map_instance_id
    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
    has_many :player_locations, DungeonCrawl.Player.Location, foreign_key: :map_tile_instance_id, on_delete: :delete_all
  end

  @doc false
  def changeset(map_tile_instance, attrs) do
    map_tile_instance
    |> cast(attrs, [:row, :col, :map_instance_id, :tile_template_id, :z_index, :character, :color, :background_color, :state, :script])
    |> validate_required([:row, :col, :map_instance_id, :z_index])
    |> TileTemplate.validate_renderables
  end
end

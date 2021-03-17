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

    field :animate_random, :boolean
    field :animate_colors, :string
    field :animate_background_colors, :string
    field :animate_characters, :string
    field :animate_period, :integer

    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
  end

  @doc false
  def changeset(map_tile, attrs) do
    map_tile
    |> cast(attrs, [:row,
                    :col,
                    :dungeon_id,
                    :tile_template_id,
                    :z_index,
                    :character,
                    :color,
                    :background_color,
                    :state,
                    :script,
                    :name,
                    :animate_random,
                    :animate_colors,
                    :animate_background_colors,
                    :animate_characters,
                    :animate_period])
    |> validate_required([:row, :col, :dungeon_id, :z_index])
    |> validate_length(:name, max: 32)
    |> TileTemplate.validate_animation_fields
    |> TileTemplate.validate_renderables
    |> TileTemplate.validate_state_values
    # TODO: validate the script (before actually saving it)
  end
end

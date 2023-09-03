defmodule DungeonCrawl.DungeonInstances.Tile do
  use Ecto.Schema
  import Ecto.Changeset

  # This is where the validations for color, background_color, and character live for now.
  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "tile_instances" do
    field :row, :integer
    field :col, :integer
    field :z_index, :integer, default: 0

    field :name, :string

    field :background_color, :string
    field :character, :string
    field :color, :string

    field :state, DungeonCrawl.EctoStateValueMap, default: %{}
    field :script, :string, default: ""
#    field :parsed_state, :map, virtual: true

    field :animate_random, :boolean
    field :animate_colors, :string
    field :animate_background_colors, :string
    field :animate_characters, :string
    field :animate_period, :integer

    belongs_to :level, DungeonCrawl.DungeonInstances.Level, foreign_key: :level_instance_id
    has_one :player_location, DungeonCrawl.Player.Location, foreign_key: :tile_instance_id, on_delete: :delete_all
  end

  @doc false
  def changeset(tile_instance, attrs) do
    tile_instance
    |> cast(attrs, [:row,
                    :col,
                    :level_instance_id,
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
    |> validate_required([:row, :col, :level_instance_id, :z_index])
    |> TileTemplate.validate_animation_fields
    |> TileTemplate.validate_renderables
    |> TileTemplate.validate_state_values
  end
end

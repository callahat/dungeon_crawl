defmodule DungeonCrawl.Dungeons.Tile do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Dungeons.Level
  # This is where the validations for color, background_color, and character live for now.
  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "tiles" do
    field :row, :integer
    field :col, :integer
    field :z_index, :integer, default: 0

    field :name, :string

    field :background_color, :string
    field :character, :string
    field :color, :string

    field :state, DungeonCrawl.EctoStateValueMap, default: %{}
    field :script, :string, default: ""

    field :animate_random, :boolean
    field :animate_colors, :string
    field :animate_background_colors, :string
    field :animate_characters, :string
    field :animate_period, :integer

    field :state_variables, {:array, :string}, virtual: true, default: nil
    field :state_values, {:array, :string}, virtual: true, default: nil

    belongs_to :level, Level
    belongs_to :tile_template, TileTemplate
  end

  @doc false
  def changeset(tile, attrs) do
    tile
    |> cast(attrs, [:row,
                    :col,
                    :level_id,
                    :tile_template_id,
                    :z_index,
                    :character,
                    :color,
                    :background_color,
                    :state_variables,
                    :state_values,
                    :state,
                    :script,
                    :name,
                    :animate_random,
                    :animate_colors,
                    :animate_background_colors,
                    :animate_characters,
                    :animate_period],
         empty_values: [""])
    |> validate_required([:row, :col, :level_id, :z_index])
    |> validate_length(:name, max: 32)
    |> TileTemplate.validate_animation_fields
    |> TileTemplate.validate_renderables
    |> TileTemplate.validate_state_values
    # TODO: validate the script (before actually saving it)
  end
end

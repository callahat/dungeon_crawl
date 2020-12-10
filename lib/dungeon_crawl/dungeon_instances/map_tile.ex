defmodule DungeonCrawl.DungeonInstances.MapTile do
  use Ecto.Schema
  import Ecto.Changeset

  # This is where the validations for color, background_color, and character live for now.
  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "map_tile_instances" do
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

    belongs_to :dungeon, DungeonCrawl.DungeonInstances.Map, foreign_key: :map_instance_id
    has_many :player_locations, DungeonCrawl.Player.Location, foreign_key: :map_tile_instance_id, on_delete: :delete_all
  end

  @doc false
  def changeset(map_tile_instance, attrs) do
    map_tile_instance
    |> cast(attrs, [:row,
                    :col,
                    :map_instance_id,
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
    |> validate_required([:row, :col, :map_instance_id, :z_index])
    |> TileTemplate.validate_animation_fields
    |> TileTemplate.validate_renderables
    |> TileTemplate.validate_state_values
  end
end

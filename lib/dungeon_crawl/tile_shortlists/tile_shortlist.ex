defmodule DungeonCrawl.TileShortlists.TileShortlist do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "tile_shortlists" do
    field :background_color, :string
    field :character, :string
    field :color, :string
    field :description, :string
    field :name, :string

    field :slug, :string
    field :script, :string, default: ""
    field :state, :string

    field :animate_random, :boolean
    field :animate_colors, :string
    field :animate_background_colors, :string
    field :animate_characters, :string
    field :animate_period, :integer

    belongs_to :tile_template, DungeonCrawl.TileTemplates.TileTemplate
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(tile_shortlist, attrs) do
    tile_shortlist
    |> cast(attrs, [:background_color,
                    :character,
                    :color,
                    :description,
                    :name,
                    :slug,
                    :script,
                    :state,
                    :animate_random,
                    :animate_colors,
                    :animate_background_colors,
                    :animate_characters,
                    :animate_period,
                    :tile_template_id,
                    :user_id])
    |> validate_length(:name, max: 32)
    |> validate_required([:user_id])
    |> TileTemplate.validate_animation_fields
    |> TileTemplate.validate_renderables
    |> TileTemplate.validate_state_values
  end
end

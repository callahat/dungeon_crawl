defmodule DungeonCrawl.TileShortlists.TileShortlist do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates
  alias DungeonCrawl.TileTemplates.TileTemplate

  @key_attributes [:background_color,
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
                   :tile_template_id]
  @changeset_attributes [:user_id | @key_attributes ]

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
  def key_attributes() do
    @key_attributes
  end

  @doc false
  def changeset(tile_shortlist, %TileTemplate{} = attrs) do
    changeset(tile_shortlist, Map.drop(attrs, [:__meta__, :__struct__, :user_id]))
  end

  @doc false
  def changeset(tile_shortlist, attrs) do
    tile_shortlist
    |> cast(attrs, @changeset_attributes)
    |> validate_length(:name, max: 32)
    |> validate_required([:user_id])
    |> _validate_tile_template_id
    |> TileTemplate.validate_animation_fields
    |> TileTemplate.validate_renderables
    |> TileTemplate.validate_state_values
    |> TileTemplate.validate_script(tile_shortlist.user_id)
  end

  defp _validate_tile_template_id(changeset) do
    if tile_template_id = get_field(changeset, :tile_template_id) do
      _validate_tile_template_not_historic(changeset, TileTemplates.get_tile_template(tile_template_id))
    else
      changeset
    end
  end

  defp _validate_tile_template_not_historic(changeset, nil) do
    add_error(changeset, :tile_template_id, "tile template does not exist")
  end
  defp _validate_tile_template_not_historic(changeset, %{deleted_at: nil}), do: changeset
  defp _validate_tile_template_not_historic(changeset, _historic) do
    add_error(changeset, :tile_template_id, "cannot shortlist an historic tile template")
  end
end

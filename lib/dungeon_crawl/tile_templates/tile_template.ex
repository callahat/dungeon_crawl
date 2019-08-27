defmodule DungeonCrawl.TileTemplates.TileTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @color_match ~r/\A(?:[a-z]+|#(?:[\da-f]{3}){1,2})\z/i

  alias DungeonCrawl.EventResponder.Parser

  schema "tile_templates" do
    field :active, :boolean, default: false
    field :background_color, :string
    field :character, :string
    field :color, :string
    field :description, :string
    field :deleted_at, :naive_datetime
    field :name, :string
    field :public, :boolean, default: false
    field :responders, :string, default: "{}"
    field :state, :string
    field :version, :integer, default: 1
    has_many :map_tiles, DungeonCrawl.Dungeon.MapTile
    belongs_to :previous_version, DungeonCrawl.TileTemplates.TileTemplate, foreign_key: :previous_version_id
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(tile_template, attrs) do
    tile_template
    |> cast(attrs, [:name, :character, :description, :color, :background_color, :responders,:version,:active,:public,:previous_version_id,:deleted_at,:user_id,:state])
    |> validate_required([:name, :description])
    |> validate_renderables
    |> validate_responders
  end

  @doc false
  def validate_renderables(changeset) do
    changeset
    |> validate_format(:color, @color_match)
    |> validate_format(:background_color, @color_match)
    |> validate_length(:character, min: 1, max: 1)
  end

  @doc false
  def validate_responders(changeset) do
    responders = get_field(changeset, :responders)
    _validate_responders(changeset, responders)
  end

  defp _validate_responders(changeset, nil), do: changeset
  defp _validate_responders(changeset, responders) do
    case Parser.parse(responders) do
      {:error, message, bad_part} -> add_error(changeset, :responders, "#{message} - #{bad_part}")
      {:ok, _}                    -> changeset
    end
  end
end

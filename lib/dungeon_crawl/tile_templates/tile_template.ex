defmodule DungeonCrawl.TileTemplates.TileTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.EventResponder.Parser

  schema "tile_templates" do
    field :background_color, :string
    field :character, :string
    field :color, :string
    field :description, :string
    field :name, :string
    field :responders, :string, default: "{}"

    timestamps()
  end

  @doc false
  def changeset(tile_template, attrs) do
    tile_template
    |> cast(attrs, [:name, :character, :description, :color, :background_color, :responders])
    |> validate_required([:name, :character, :description])
    |> validate_responders
  end

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

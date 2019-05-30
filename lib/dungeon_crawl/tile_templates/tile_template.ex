defmodule DungeonCrawl.TileTemplates.TileTemplate do
  use Ecto.Schema
  import Ecto.Changeset


  schema "tile_templates" do
    field :background_color, :string
    field :blocking, :boolean, default: false
    field :character, :string
    field :closeable, :boolean, default: false
    field :color, :string
    field :description, :string
    field :durability, :integer
    field :name, :string
    field :openable, :boolean, default: false

    timestamps()
  end

  @doc false
  def changeset(tile_template, attrs) do
    tile_template
    |> cast(attrs, [:name, :character, :description, :color, :background_color, :blocking, :openable, :closeable, :durability])
    |> validate_required([:name, :character, :description])
  end
end

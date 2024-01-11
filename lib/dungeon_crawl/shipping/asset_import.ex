defmodule DungeonCrawl.Shipping.AssetImport do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Shipping.Import

  schema "asset_imports" do
    field :attributes, :map
    field :action, Ecto.Enum, values: [waiting: 1, create_new: 2, update_existing: 3, resolved: 4], default: :waiting
    field :importing_slug, :string
    field :existing_slug, :string
    field :resolved_slug, :string
    field :type, Ecto.Enum, values: [items: 1, sounds: 2, tile_templates: 3]
    belongs_to :dungeon_import, Import

    timestamps()
  end

  @doc false
  def changeset(asset_import, attrs) do
    asset_import
    |> cast(attrs, [:dungeon_import_id, :type, :importing_slug, :existing_slug, :resolved_slug, :action, :attributes])
    |> validate_required([:dungeon_import_id, :type, :importing_slug, :existing_slug, :action])
  end
end

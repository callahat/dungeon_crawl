defmodule DungeonCrawl.Equipment.Item do
  use DungeonCrawl.AttributeQueryable
  use DungeonCrawl.Sluggable
  use Ecto.Schema
  import Ecto.Changeset
  import DungeonCrawl.TileTemplates.TileTemplate, only: [validate_script: 2]

  schema "items" do
    field :name, :string
    field :description, :string
    field :public, :boolean, default: false
    field :weapon, :boolean, default: false
    field :consumable, :boolean, default: false
    field :script, :string
    field :slug, :string
    field :program, :map, virtual: true

    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :script, :public, :user_id, :weapon, :consumable])
    |> validate_required([:name, :script, :public])
    |> validate_script(item.user_id || attrs[:user_id])
    |> unique_constraint(:slug, name: :items_slug_index, message: "Slug already exists")
  end
end

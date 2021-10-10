defmodule DungeonCrawl.Equipment.Item do
  use Ecto.Schema
  import Ecto.Changeset
  import DungeonCrawl.TileTemplates.TileTemplate, only: [validate_script: 2]

  schema "items" do
    field :name, :string
    field :description, :string
    field :public, :boolean, default: false
    field :script, :string
    field :slug, :string

    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :script, :public, :user_id])
    |> validate_required([:name, :script, :public])
    |> validate_script(item.user_id || attrs[:user_id])
  end
end

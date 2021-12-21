defmodule DungeonCrawl.Sound.Effect do
  use Ecto.Schema
  import Ecto.Changeset

  schema "effects" do
    field :name, :string
    field :slug, :string
    field :public, :boolean, default: false
    field :zzfx_params, :string

    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(effect, attrs) do
    effect
    |> cast(attrs, [:name, :zzfx_params, :public, :user_id])
    |> validate_required([:name, :zzfx_params])
  end
end

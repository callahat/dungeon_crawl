defmodule DungeonCrawl.Shipping.Export do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Dungeons.Dungeon

  schema "dungeon_exports" do
    field :data, :string
    field :status, Ecto.Enum, values: [queued: 1, running: 2, completed: 3, failed: 4], default: :queued
    belongs_to :dungeon, Dungeon
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(export, attrs) do
    export
    |> cast(attrs, [:dungeon_id, :user_id, :status, :data])
    |> validate_required([:dungeon_id, :user_id, :status, :data])
  end
end

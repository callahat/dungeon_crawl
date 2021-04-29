defmodule DungeonCrawl.Scores.Score do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scores" do
    field :deaths, :integer, default: 0
    field :duration, :integer
    field :result, :string
    field :score, :integer
    field :steps, :integer
    field :victory, :boolean, default: false
    field :user_id_hash, :string

    field :user, :map, virtual: true
    field :place, :integer, virtual: true

    belongs_to :map_set, DungeonCrawl.Dungeon.MapSet, foreign_key: :map_set_id

    timestamps()
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:user_id_hash, :score, :steps, :duration, :result, :victory, :map_set_id, :deaths])
    |> validate_required([:user_id_hash, :score, :map_set_id])
  end
end

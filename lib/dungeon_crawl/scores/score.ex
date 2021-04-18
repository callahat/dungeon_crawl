defmodule DungeonCrawl.Scores.Score do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scores" do
    field :duration, :time
    field :result, :string
    field :score, :integer
    field :steps, :integer
    field :victory, :boolean, default: false
    field :user_id_hash, :string

    belongs_to :map_set, DungeonCrawl.Dungeon.MapSet, foreign_key: :map_set_id

    timestamps()
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:user_id_hash, :score, :steps, :duration, :result, :victory, :map_set_id])
    |> validate_required([:user_id_hash, :score, :map_set_id])
  end
end

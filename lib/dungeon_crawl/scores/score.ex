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

    belongs_to :dungeon, DungeonCrawl.Dungeons.Dungeon

    timestamps()
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:user_id_hash, :score, :steps, :duration, :result, :victory, :dungeon_id, :deaths])
    |> validate_required([:user_id_hash, :score])
  end
end

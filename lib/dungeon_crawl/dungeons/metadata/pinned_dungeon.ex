defmodule DungeonCrawl.Dungeons.Metadata.PinnedDungeon do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pinned_dungeons" do
    field :line_identifier, :integer

    timestamps()
  end

  @doc false
  def changeset(pinned_dungeon, attrs) do
    pinned_dungeon
    |> cast(attrs, [:line_identifier])
    |> validate_required([:line_identifier])
    |> unique_constraint([:line_identifier], message: "already pinned")
  end
end

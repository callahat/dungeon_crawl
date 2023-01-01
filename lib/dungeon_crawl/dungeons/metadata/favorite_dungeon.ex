defmodule DungeonCrawl.Dungeons.Metadata.FavoriteDungeon do
  use Ecto.Schema
  import Ecto.Changeset

  schema "favorite_dungeons" do
    field :line_identifier, :integer
    field :user_id_hash, :string

    timestamps()
  end

  @doc false
  def changeset(favorite_dungeon, attrs) do
    favorite_dungeon
    |> cast(attrs, [:user_id_hash, :line_identifier])
    |> validate_required([:user_id_hash, :line_identifier])
    |> unique_constraint([:user_id_hash, :line_identifier], message: "already a favorite")
  end
end

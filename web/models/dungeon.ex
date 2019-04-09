defmodule DungeonCrawl.Dungeon do
  use DungeonCrawl.Web, :model

  schema "dungeons" do
    field :name, :string
    has_many :dungeon_map_tiles, DungeonCrawl.DungeonMapTile, on_delete: :delete_all

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name])
    |> cast_assoc(:dungeon_map_tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:name])
  end
end

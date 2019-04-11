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

  @doc """
  Generates the dungeon_map_tiles map, which can be fed into `Repo.insert_all/2`
  """
  def generate_dungeon_map_tiles(dungeon, dungeon_generator, timestamp) do
    dungeon_generator.generate
    |> Enum.to_list
    |> Enum.map(fn({{row,col}, tile}) -> dungeon_map_tile_map(dungeon.id, row, col, tile, timestamp) end)
  end

  defp dungeon_map_tile_map(dungeon_id, row, col, tile, timestamp) do
    %{dungeon_id: dungeon_id, row: row, col: col, tile: to_string([tile]), inserted_at: timestamp, updated_at: timestamp}
  end
end

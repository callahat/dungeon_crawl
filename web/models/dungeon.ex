defmodule DungeonCrawl.Dungeon do
  use DungeonCrawl.Web, :model

  schema "dungeons" do
    field :name, :string
    field :width, :integer, default: 80
    field :height, :integer, default: 40

    has_many :dungeon_map_tiles, DungeonCrawl.DungeonMapTile, on_delete: :delete_all

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name,:height,:width])
    |> cast_assoc(:dungeon_map_tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:name])
    |> validate_inclusion(:height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:width, 20..120, message: "must be between 20 and 120")
  end

  @doc """
  Generates the dungeon_map_tiles map, which can be fed into `Repo.insert_all/2`
  """
  def generate_dungeon_map_tiles(dungeon, dungeon_generator) do
    dungeon_generator.generate(dungeon.height, dungeon.width)
    |> Enum.to_list
    |> Enum.map(fn({{row,col}, tile}) -> dungeon_map_tile_map(dungeon.id, row, col, tile) end)
  end

  defp dungeon_map_tile_map(dungeon_id, row, col, tile) do
    %{dungeon_id: dungeon_id, row: row, col: col, tile: to_string([tile])}
  end
end

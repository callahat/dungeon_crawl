defmodule DungeonCrawl.Dungeon.SpawnLocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spawn_locations" do
    field :col, :integer
    field :row, :integer
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
  end

  @doc false
  def changeset(spawn_location, attrs, dungeon_height, dungeon_width) do
    spawn_location
    |> cast(attrs, [:dungeon_id, :row, :col])
    |> validate_required([:dungeon_id, :row, :col])
    |> unique_constraint(:dungeon_id, name: :spawn_locations_dungeon_id_row_col_index, message: "Spawn location already exists")
    |> validate_inclusion(:row, 0..dungeon_height-1, message: "must be between 0 and #{dungeon_height-1}")
    |> validate_inclusion(:col, 0..dungeon_width-1, message: "must be between 0 and #{dungeon_width-1}")
  end
end

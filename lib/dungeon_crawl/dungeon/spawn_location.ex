defmodule DungeonCrawl.Dungeon.SpawnLocation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spawn_locations" do
    field :col, :integer
    field :row, :integer
    belongs_to :dungeon, DungeonCrawl.Dungeon.Map
  end

  @doc false
  def changeset(spawn_location, attrs) do
    spawn_location
    |> cast(attrs, [:dungeon_id, :row, :col])
    |> validate_required([:dungeon_id, :row, :col])
    |> unique_constraint(:dungeon_id, name: :spawn_locations_dungeon_id_row_col_index)
  end
end

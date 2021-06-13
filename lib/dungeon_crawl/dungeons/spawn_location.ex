defmodule DungeonCrawl.Dungeons.SpawnLocation do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Dungeons.Level

  schema "spawn_locations" do
    field :col, :integer
    field :row, :integer
    belongs_to :level, Level
  end

  @doc false
  def changeset(spawn_location, attrs, level_height, level_width) do
    spawn_location
    |> cast(attrs, [:level_id, :row, :col])
    |> validate_required([:level_id, :row, :col])
    |> unique_constraint(:level_id, name: :spawn_locations_level_id_row_col_index, message: "Spawn location already exists")
    |> validate_inclusion(:row, 0..level_height-1, message: "must be between 0 and #{level_height-1}")
    |> validate_inclusion(:col, 0..level_width-1, message: "must be between 0 and #{level_width-1}")
  end
end

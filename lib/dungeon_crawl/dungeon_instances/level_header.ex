defmodule DungeonCrawl.DungeonInstances.LevelHeader do
  use Ecto.Schema
  import Ecto.Changeset

  schema "level_headers" do
    field :number, :integer
    field :type, :integer
    belongs_to :level, DungeonCrawl.Dungeons.Level, foreign_key: :level_id
    belongs_to :dungeon_instance, DungeonCrawl.DungeonInstances.Tile, foreign_key: :dungeon_instance_id
    has_many :level_instances, DungeonCrawl.DungeonInstances.Level, foreign_key: :level_header_id

    timestamps()
  end

  @doc false
  def changeset(level_header, attrs) do
    level_header
    |> cast(attrs, [:number, :type])
    |> validate_required([:number, :type])
  end
end

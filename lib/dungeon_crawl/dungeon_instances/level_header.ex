defmodule DungeonCrawl.DungeonInstances.LevelHeader do
  use Ecto.Schema
  import Ecto.Changeset

  schema "level_headers" do
    field :number, :integer
    field :type, Ecto.Enum, values: [universal: 1, solo: 2], default: :universal
    belongs_to :level, DungeonCrawl.Dungeons.Level, foreign_key: :level_id
    belongs_to :dungeon, DungeonCrawl.DungeonInstances.Dungeon, foreign_key: :dungeon_instance_id
    has_many :levels, DungeonCrawl.DungeonInstances.Level, on_delete: :delete_all, foreign_key: :level_header_id
    has_many :locations, through: [:levels, :tiles, :player_location], on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(level_header, attrs) do
    level_header
    |> cast(attrs, [:number, :type, :dungeon_instance_id, :level_id])
    |> validate_required([:number, :type])
    |> unique_constraint(:number, name: :level_headers_dungeon_number_index, message: "Level Number already exists")
  end
end

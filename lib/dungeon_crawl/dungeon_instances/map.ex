defmodule DungeonCrawl.DungeonInstances.Map do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "map_instances" do
    field :height, :integer
    field :name, :string
    field :width, :integer
    field :state, :string

    belongs_to :dungeon, DungeonCrawl.Dungeon.Map, foreign_key: :map_id
    has_many :dungeon_map_tiles, DungeonCrawl.DungeonInstances.MapTile, foreign_key: :map_instance_id, on_delete: :delete_all
    has_many :locations, through: [:dungeon_map_tiles, :player_locations], on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(dungeon_instance, attrs) do
    # Probably don't need all these validations as it will copy them from the dungeon, which already has these validations
    dungeon_instance
    |> cast(attrs, [:name,:height,:width,:map_id,:state])
    |> cast_assoc(:dungeon_map_tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:name, :map_id, :height, :width])
    |> validate_inclusion(:height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:width, 20..120, message: "must be between 20 and 120")
    |> TileTemplate.validate_state_values
  end
end

defmodule DungeonCrawl.DungeonInstances.Map do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "map_instances" do
    field :height, :integer
    field :name, :string
    field :number, :integer, default: 1
    field :entrance, :boolean
    field :width, :integer
    field :state, :string

    belongs_to :dungeon, DungeonCrawl.Dungeon.Map, foreign_key: :map_id
    belongs_to :map_set, DungeonCrawl.DungeonInstances.MapSet, foreign_key: :map_set_instance_id
    has_many :dungeon_map_tiles, DungeonCrawl.DungeonInstances.MapTile, foreign_key: :map_instance_id, on_delete: :delete_all
    has_many :locations, through: [:dungeon_map_tiles, :player_locations], on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(dungeon_instance, attrs) do
    # Probably don't need all these validations as it will copy them from the dungeon, which already has these validations
    dungeon_instance
    |> cast(attrs, [:name, :map_set_instance_id, :map_id, :number, :entrance, :height, :width, :state])
    |> cast_assoc(:dungeon_map_tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:map_id, :map_set_instance_id, :height, :width])
    |> validate_inclusion(:height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:width, 20..120, message: "must be between 20 and 120")
    |> unique_constraint(:number, name: :map_instances_map_set_instance_id_number_index, message: "Level Number already exists")
    |> TileTemplate.validate_state_values
  end
end

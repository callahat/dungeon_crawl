defmodule DungeonCrawl.DungeonInstances.MapSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "map_set_instances" do
    field :autogenerated, :boolean, default: false
    field :name, :string
    field :state, :string

    belongs_to :map_set, DungeonCrawl.Dungeon.MapSet
    has_many :maps, DungeonCrawl.DungeonInstances.Map, foreign_key: :map_set_instance_id, on_delete: :delete_all
    has_many :locations, through: [:maps, :dungeon_map_tiles, :player_locations], on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(map_set_instance, attrs) do
    # Probably don't need all these validations as it will copy them from the dungeon, which already has these validations
    map_set_instance
    |> cast(attrs, [:name,:map_set_id,:state,:autogenerated])
    |> cast_assoc(:maps)
    |> validate_length(:name, max: 32)
    |> validate_required([:name, :map_set_id])
    |> TileTemplate.validate_state_values
  end
end

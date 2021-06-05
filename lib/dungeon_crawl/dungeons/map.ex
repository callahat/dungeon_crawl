defmodule DungeonCrawl.Dungeons.Map do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.TileTemplates.TileTemplate
  # TODO: remove some of these fields that have been moved to map_sets, rename dungeons to map to standardize
  schema "dungeons" do
    field :name, :string
    field :number, :integer, default: 1
    field :entrance, :boolean
    field :width, :integer
    field :height, :integer
    field :state, :string

    field :number_north, :integer
    field :number_south, :integer
    field :number_east, :integer
    field :number_west, :integer

    has_many :map_instances, DungeonInstances.Map, foreign_key: :map_id
    has_many :dungeon_map_tiles, Dungeons.MapTile, foreign_key: :dungeon_id, on_delete: :delete_all
    has_many :spawn_locations, Dungeons.SpawnLocation, foreign_key: :dungeon_id, on_delete: :delete_all
    has_many :locations, through: [:map_instances, :locations], on_delete: :delete_all
    belongs_to :map_set, Dungeons.MapSet

    timestamps()
  end

  @doc false
  def changeset(map, attrs) do
    %{max_height: max_height, max_width: max_width} = Map.take(Admin.get_setting, [:max_height, :max_width])
    map
    |> cast(attrs, [:name, :map_set_id, :number, :entrance, :height, :width, :state,
                    :number_north, :number_south, :number_east, :number_west])
    |> cast_assoc(:dungeon_map_tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:map_set_id, :number, :height, :width])
    |> validate_inclusion(:height, 20..max_height, message: "must be between 20 and #{max_height}")
    |> validate_inclusion(:width, 20..max_width, message: "must be between 20 and #{max_width}")
    |> unique_constraint(:number, name: :dungeons_map_set_id_number_index, message: "Level Number already exists")
    |> TileTemplate.validate_state_values
  end
end

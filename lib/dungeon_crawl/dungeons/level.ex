defmodule DungeonCrawl.Dungeons.Level do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.TileTemplates.TileTemplate
  # TODO: remove some of these fields that have been moved to dungeons, rename dungeons to map to standardize
  schema "levels" do
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

    field :state_variables, {:array, :string}, virtual: true, default: nil
    field :state_values, {:array, :string}, virtual: true, default: nil

    has_many :level_instances, DungeonInstances.Level#, foreign_key: :level_id
    has_many :tiles, Dungeons.Tile, on_delete: :delete_all#, foreign_key: :level_id
    has_many :spawn_locations, Dungeons.SpawnLocation, foreign_key: :level_id, on_delete: :delete_all
    has_many :locations, through: [:level_instances, :locations], on_delete: :delete_all
    belongs_to :dungeon, Dungeons.Dungeon

    timestamps()
  end

  @doc false
  def changeset(level, attrs) do
    %{max_height: max_height, max_width: max_width} = Map.take(Admin.get_setting, [:max_height, :max_width])
    level
    |> cast(attrs, [:name,
                    :dungeon_id,
                    :number,
                    :entrance,
                    :height,
                    :width,
                    :state_variables,
                    :state_values,
                    :state,
                    :number_north,
                    :number_south,
                    :number_east,
                    :number_west])
    |> cast_assoc(:tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:dungeon_id, :number, :height, :width])
    |> validate_inclusion(:height, 20..max_height, message: "must be between 20 and #{max_height}")
    |> validate_inclusion(:width, 20..max_width, message: "must be between 20 and #{max_width}")
    |> unique_constraint(:number, name: :levels_dungeon_id_number_index, message: "Level Number already exists")
    |> TileTemplate.validate_state_values
  end
end

defmodule DungeonCrawl.DungeonInstances.Level do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.Games.Save

  schema "level_instances" do
    field :height, :integer
    field :name, :string
    field :number, :integer, default: 1
    field :entrance, :boolean
    field :width, :integer
    field :state, :string

    field :number_north, :integer
    field :number_south, :integer
    field :number_east, :integer
    field :number_west, :integer

    belongs_to :level, DungeonCrawl.Dungeons.Level
    # Should this direct link go away since the level is a child of the header, which is also a child of dungeon instance?
    belongs_to :dungeon, DungeonCrawl.DungeonInstances.Dungeon, foreign_key: :dungeon_instance_id
    belongs_to :level_header, DungeonCrawl.DungeonInstances.LevelHeader
    belongs_to :player_location, DungeonCrawl.Player.Location
    has_many :tiles, DungeonCrawl.DungeonInstances.Tile, on_delete: :delete_all, foreign_key: :level_instance_id
    has_many :locations, through: [:tiles, :player_location], on_delete: :delete_all
    has_many :spawn_locations, through: [:level, :spawn_locations]
    has_many :saves, Save, on_delete: :delete_all, foreign_key: :level_instance_id

    timestamps()
  end

  @doc false
  def changeset(level_instance, attrs) do
    # Probably don't need all these validations as it will copy them from the level, which already has these validations
    level_instance
    |> cast(attrs, [:name, :dungeon_instance_id, :level_id, :number, :entrance, :height, :width, :state,
                    :number_north, :number_south, :number_east, :number_west, :level_header_id, :player_location_id])
    |> cast_assoc(:tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:level_id, :dungeon_instance_id, :height, :width])
    |> validate_inclusion(:height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:width, 20..120, message: "must be between 20 and 120")
    |> unique_constraint(:number, name: :level_instances_dungeon_number_owned_by_player_index, message: "Level Number already exists")
    |> unique_constraint(:number, name: :level_instances_dungeon_number_shared_by_all_players_index, message: "Level Number already exists")
    |> TileTemplate.validate_state_values
  end
end

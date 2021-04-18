defmodule DungeonCrawl.Dungeon.MapSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Admin
  alias DungeonCrawl.TileTemplates.TileTemplate

  schema "map_sets" do
    field :name, :string
    field :autogenerated, :boolean, default: false
    field :version, :integer, default: 1
    field :active, :boolean, default: false
    field :state, :string
    field :deleted_at, :naive_datetime
    field :default_map_width, :integer
    field :default_map_height, :integer

    has_many :map_set_instances, DungeonCrawl.DungeonInstances.MapSet, foreign_key: :map_set_id, on_delete: :delete_all
    has_many :dungeons, DungeonCrawl.Dungeon.Map, foreign_key: :map_set_id, on_delete: :delete_all
    has_many :spawn_locations, through: [:dungeons, :spawn_locations], on_delete: :delete_all
    has_many :locations, through: [:map_set_instances, :locations], on_delete: :delete_all
    has_many :next_versions, DungeonCrawl.Dungeon.MapSet, foreign_key: :previous_version_id, on_delete: :nilify_all
    has_many :scoreboards, DungeonCrawl.Scores.Score, foreign_key: :map_set_id, on_delete: :delete_all

    belongs_to :previous_version, DungeonCrawl.Dungeon.MapSet, foreign_key: :previous_version_id
    belongs_to :user, DungeonCrawl.Account.User

    timestamps()
  end

  @doc false
  def changeset(map_set, attrs) do
    %{max_height: max_height, max_width: max_width} = Map.take(Admin.get_setting, [:max_height, :max_width])
    map_set
    |> cast(attrs, [:name,:version,:autogenerated,:active,:previous_version_id,:deleted_at,:user_id,:state,:default_map_width,:default_map_height])
    |> cast_assoc(:dungeons)
    |> validate_length(:name, max: 32)
    |> validate_required([:name])
    |> validate_inclusion(:default_map_height, 20..max_height, message: "must be between 20 and #{max_height}")
    |> validate_inclusion(:default_map_width, 20..max_width, message: "must be between 20 and #{max_width}")
    |> TileTemplate.validate_state_values
  end
end

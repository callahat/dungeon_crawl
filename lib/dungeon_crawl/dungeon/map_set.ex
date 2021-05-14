defmodule DungeonCrawl.Dungeon.MapSet do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeon
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
    field :line_identifier, :integer
    field :score_count, :integer, virtual: true, default: 0

    has_many :map_set_instances, DungeonCrawl.DungeonInstances.MapSet, foreign_key: :map_set_id, on_delete: :delete_all
    has_many :dungeons, DungeonCrawl.Dungeon.Map, foreign_key: :map_set_id, on_delete: :delete_all
    has_many :spawn_locations, through: [:dungeons, :spawn_locations], on_delete: :delete_all
    has_many :locations, through: [:map_set_instances, :locations], on_delete: :delete_all
    has_many :next_versions, DungeonCrawl.Dungeon.MapSet, foreign_key: :previous_version_id, on_delete: :nilify_all
    has_many :scores, DungeonCrawl.Scores.Score, foreign_key: :map_set_id, on_delete: :delete_all

    belongs_to :previous_version, DungeonCrawl.Dungeon.MapSet, foreign_key: :previous_version_id
    belongs_to :user, DungeonCrawl.Account.User
    belongs_to :title_dungeon, DungeonCrawl.Dungeon.Map, foreign_key: :title_map_id

    timestamps()
  end

  @doc false
  def changeset(map_set, attrs) do
    %{max_height: max_height, max_width: max_width} = Map.take(Admin.get_setting, [:max_height, :max_width])
    map_set
    |> cast(attrs, [:name,:version,:autogenerated,:active,:previous_version_id,:deleted_at,:user_id,:state,:default_map_width,:default_map_height, :line_identifier, :title_map_id])
    |> cast_assoc(:dungeons)
    |> validate_length(:name, max: 32)
    |> validate_required([:name])
    |> _validate_title_map()
    |> validate_inclusion(:default_map_height, 20..max_height, message: "must be between 20 and #{max_height}")
    |> validate_inclusion(:default_map_width, 20..max_width, message: "must be between 20 and #{max_width}")
    |> TileTemplate.validate_state_values
  end

  defp _validate_title_map(%{changes: %{title_map_id: nil}} = changeset), do: changeset
  defp _validate_title_map(%{data: %{id: id}, changes: %{title_map_id: title_map_id}} = changeset) do
    with %Dungeon.Map{} = title_map <- Dungeon.get_map(title_map_id),
         ^id <- title_map.map_set_id do
      changeset
    else
      _ -> add_error(changeset, :title_map_id, "invalid title_map_id")
    end
  end
  defp _validate_title_map(changeset), do: changeset
end

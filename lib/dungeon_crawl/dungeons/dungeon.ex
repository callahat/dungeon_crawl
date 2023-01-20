defmodule DungeonCrawl.Dungeons.Dungeon do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Admin
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.DungeonInstances
  alias DungeonCrawl.TileTemplates.TileTemplate
  alias DungeonCrawl.Account
  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Equipment
  alias DungeonCrawl.Scores.Score
  alias DungeonCrawl.StateValue

  schema "dungeons" do
    field :name, :string
    field :description, :string
    field :autogenerated, :boolean, default: false
    field :version, :integer, default: 1
    field :active, :boolean, default: false
    field :state, :string
    field :deleted_at, :naive_datetime
    field :default_map_width, :integer
    field :default_map_height, :integer
    field :line_identifier, :integer
    field :score_count, :integer, virtual: true, default: 0
    field :title_number, :integer
    field :importing, :boolean, default: false

    # Note: state_variables are essentially keys, state_values are the values, both get zipped
    # together and converted to a string to be stored as the state
    field :state_variables, {:array, :string}, virtual: true, default: nil
    field :state_values, {:array, :string}, virtual: true, default: nil

    field :pinned, :boolean, virtual: true, default: nil
    field :favorited, :boolean, virtual: true, default: nil

    has_many :dungeon_instances, DungeonInstances.Dungeon, on_delete: :delete_all#, foreign_key: :map_set_id
    has_many :public_dungeon_instances, DungeonInstances.Dungeon, where: [is_private: false]
    has_many :levels, Dungeons.Level, on_delete: :delete_all#, foreign_key: :map_set_id
    has_many :spawn_locations, through: [:levels, :spawn_locations], on_delete: :delete_all
    has_many :locations, through: [:dungeon_instances, :locations], on_delete: :delete_all
    has_many :next_versions, Dungeons.Dungeon, foreign_key: :previous_version_id, on_delete: :nilify_all
    has_many :scores, Score, on_delete: :delete_all#, foreign_key: :map_set_id

    belongs_to :previous_version, Dungeons.Dungeon, foreign_key: :previous_version_id
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(dungeon, attrs) do
    %{max_height: max_height, max_width: max_width} = Map.take(Admin.get_setting, [:max_height, :max_width])
    dungeon
    |> cast(attrs, [:name,
                    :description,
                    :version,
                    :autogenerated,
                    :active,
                    :previous_version_id,
                    :deleted_at,
                    :user_id,
                    :state_variables,
                    :state_values,
                    :state,
                    :default_map_width,
                    :default_map_height,
                    :line_identifier,
                    :title_number,
                    :importing])
    |> cast_assoc(:levels)
    |> validate_length(:name, max: 32)
    |> validate_length(:description, max: 1024)
    |> validate_required([:name])
    |> validate_inclusion(:default_map_height, 20..max_height, message: "must be between 20 and #{max_height}")
    |> validate_inclusion(:default_map_width, 20..max_width, message: "must be between 20 and #{max_width}")
    |> TileTemplate.validate_state_values
    |> _validate_starting_equipment()
  end

  defp _validate_starting_equipment(changeset) do
    user_id = if Map.has_key?(changeset.changes, :user_id),
                do: changeset.changes[:user_id],
                else: changeset.data.user_id

    with {:ok, parsed_state} <- StateValue.Parser.parse(changeset.changes[:state]),
         %{starting_equipment: se} <- parsed_state,
         author <- Account.get_user(user_id),
         invalid_equipment when invalid_equipment != [] <- _invalid_equipment(se, author) do
      add_error(changeset, :base, "starting_equipment contains invalid items: `#{inspect invalid_equipment}}`")
    else
      _ -> changeset
    end
  end

  defp _invalid_equipment(equipment, author) do
    String.split(equipment)
    |> Enum.map(fn item_slug ->
         {item_slug, Equipment.get_item(item_slug, author)}
       end)
    |> Enum.reject(fn {_, item} -> item end)
    |> Enum.map( fn {item_slug, _} -> item_slug end)
  end
end

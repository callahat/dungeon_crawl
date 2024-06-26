defmodule DungeonCrawl.Shipping.Import do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Dungeons
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Shipping

  schema "dungeon_imports" do
    field :data, :string
    field :line_identifier, :integer
    field :file_name, :string
    field :status, Ecto.Enum, values: [queued: 1, running: 2, completed: 3, failed: 4, waiting: 5], default: :queued
    field :details, :string
    field :log, :string, default: ""
    belongs_to :dungeon, Dungeon
    belongs_to :user, User

    # todo: might be better to create a specialized function to load the imports as well as matches,
    # as these will be used on the reconciliation page
    has_many :asset_imports, DungeonCrawl.Shipping.AssetImport, foreign_key: :dungeon_import_id

    timestamps()
  end

  @doc false
  def changeset(import, attrs) do
    import
    |> cast(attrs, [:dungeon_id, :user_id, :status, :details, :data, :line_identifier, :file_name, :log])
    |> validate_required([:user_id, :status, :data, :file_name])
    |> _validate_not_already_queued()
    |> _validate_line_identifier()
  end

  defp _validate_not_already_queued(%{data: %{id: :nil}, errors: []} = changeset) do
    file_name = get_field(changeset, :file_name)
    user_id = get_field(changeset, :user_id)

    if Shipping.already_importing?(file_name, user_id) do
      add_error(changeset, :file_name, "Already importing")
    else
      changeset
    end
  end

  defp _validate_not_already_queued(changeset), do: changeset

  defp _validate_line_identifier(changeset) do
    line_identifier = get_field(changeset, :line_identifier)
    user_id = get_field(changeset, :user_id)

    if is_nil(line_identifier) ||
       Dungeons.get_newest_dungeons_version(line_identifier, user_id) do
      changeset
    else
      add_error(changeset, :line_identifier, "Invalid Line Identifier")
    end
  end
end

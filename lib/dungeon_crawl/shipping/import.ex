defmodule DungeonCrawl.Shipping.Import do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Shipping

  schema "dungeon_imports" do
    field :data, :string
    field :line_identifier, :integer
    field :file_name, :string
    field :status, Ecto.Enum, values: [queued: 1, running: 2, completed: 3, failed: 4], default: :queued
    belongs_to :dungeon, Dungeon
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(import, attrs) do
    import
    |> cast(attrs, [:dungeon_id, :user_id, :status, :data, :line_identifier, :file_name])
    |> validate_required([:user_id, :status, :data, :file_name])
    |> _validate_not_already_queued()
  end

  defp _validate_not_already_queued(%{status: :queued} = changeset) do
    file_name = get_field(changeset, :file_name)
    user_id = get_field(changeset, :user_id)

    if Shipping.already_importing?(file_name, user_id) do
      add_error(changeset, :file_name, "Already importing")
    else
      changeset
    end
  end

  defp _validate_not_already_queued(changeset), do: changeset
end

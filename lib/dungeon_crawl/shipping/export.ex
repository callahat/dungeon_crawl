defmodule DungeonCrawl.Shipping.Export do
  use Ecto.Schema
  import Ecto.Changeset

  alias DungeonCrawl.Account.User
  alias DungeonCrawl.Dungeons.Dungeon
  alias DungeonCrawl.Shipping

  schema "dungeon_exports" do
    field :data, :string
    field :file_name, :string
    field :status, Ecto.Enum, values: [queued: 1, running: 2, completed: 3, failed: 4], default: :queued
    belongs_to :dungeon, Dungeon
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(export, attrs) do
    export
    |> cast(attrs, [:dungeon_id, :user_id, :status, :data, :file_name])
    |> validate_required([:dungeon_id, :user_id, :status])
    |> _validate_not_already_queued()
  end

  defp _validate_not_already_queued(%{data: %{id: :nil}, errors: []} = changeset) do
    dungeon_id = get_field(changeset, :dungeon_id)
    user_id = get_field(changeset, :user_id)

    if Shipping.already_exporting?(dungeon_id, user_id) do
      add_error(changeset, :dungeon_id, "Already exporting")
    else
      changeset
    end
  end

  defp _validate_not_already_queued(changeset), do: changeset
end

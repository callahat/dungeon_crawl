defmodule DungeonCrawl.Games.Save do
  use Ecto.Schema
  import Ecto.Changeset

  schema "saved_games" do
    field :col, :integer
    field :row, :integer
    field :state, :string
    field :user_id_hash, :string
    belongs_to :level_instance, DungeonCrawl.DungeonInstances.Level
    has_one :dungeon_instance, through: [:level_instance, :dungeon]

    timestamps()
  end

  @doc false
  def changeset(save, attrs) do
    save
    |> cast(attrs, [:user_id_hash, :row, :col, :state, :level_instance_id])
    |> validate_required([:user_id_hash, :row, :col, :state, :level_instance_id])
  end
end

defmodule DungeonCrawl.Player.Location do
  use Ecto.Schema
  import Ecto.Changeset

  schema "player_locations" do
    field :user_id_hash, :string
    belongs_to :tile, DungeonCrawl.DungeonInstances.Tile, foreign_key: :tile_instance_id
    many_to_many :items, DungeonCrawl.Equipment.Item, join_through: "locations_items", on_delete: :delete_all, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    IO.puts "changeset"
    IO.inspect attrs[:items]
    location
    |> cast(attrs, [:user_id_hash, :tile_instance_id])
    |> _maybe_update_items(attrs[:items])
    |> validate_required([:user_id_hash, :tile_instance_id])
  end

  defp _maybe_update_items(changeset, nil), do: changeset
  defp _maybe_update_items(changeset, items), do: put_assoc(changeset, :items, items)
end

defmodule DungeonCrawl.Dungeon.Map do
  use Ecto.Schema
  import Ecto.Changeset


  schema "dungeons" do
    field :name, :string
    field :width, :integer, default: 80
    field :height, :integer, default: 40
    field :autogenerated, :boolean, default: false

    has_many :map_instances, DungeonCrawl.DungeonInstances.Map, foreign_key: :map_id
    has_many :dungeon_map_tiles, DungeonCrawl.Dungeon.MapTile, foreign_key: :dungeon_id, on_delete: :delete_all
    has_many :locations, through: [:dungeon_map_tiles, :player_locations], on_delete: :delete_all

    timestamps()
  end

  @doc false
  def changeset(map, attrs) do
    map
    |> cast(attrs, [:name,:height,:width])
    |> cast_assoc(:dungeon_map_tiles)
    |> validate_length(:name, max: 32)
    |> validate_required([:name])
    |> validate_inclusion(:height, 20..80, message: "must be between 20 and 80")
    |> validate_inclusion(:width, 20..120, message: "must be between 20 and 120")
  end

end
